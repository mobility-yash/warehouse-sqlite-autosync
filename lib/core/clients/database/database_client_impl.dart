import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/location_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/common/models/sync_metadata_model.dart';
import 'package:warehouse_data_autosync/core/common/models/warehouse_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class DatabaseClientImpl extends DatabaseClient {
  static const _dbName = 'app_data.db';
  static const _dbVersion = 1;

  Database? _database;
  Completer<Database>? _openingCompleter;

  DatabaseClientImpl();

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_openingCompleter != null) return _openingCompleter!.future;

    _openingCompleter = Completer();
    try {
      final db = await _initDatabase();
      _database = db;
      _openingCompleter!.complete(db);
      return db;
    } catch (e, st) {
      _openingCompleter!.completeError(e, st);
      rethrow;
    } finally {
      _openingCompleter = null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async => _onCreate(db),
    );
  }

  Future<void> _onCreate(Database db) async {
    // Locations
    await db.execute('''
      CREATE TABLE ${YStrings.locations} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colAddress} TEXT,
        ${YStrings.colUpdatedAt} TEXT,
        ${YStrings.colSyncedAt} TEXT
      );
    ''');

    // Warehouses
    await db.execute('''
      CREATE TABLE ${YStrings.warehouses} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colAddress} TEXT,
        ${YStrings.colUpdatedAt} TEXT,
        ${YStrings.colSyncedAt} TEXT,
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Items
    await db.execute('''
      CREATE TABLE ${YStrings.items} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colWarehouseId} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colQuantity} INTEGER,
        ${YStrings.colUpdatedAt} TEXT,
        ${YStrings.colSyncedAt} TEXT,
        FOREIGN KEY (${YStrings.colWarehouseId}) REFERENCES ${YStrings.warehouses} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Notifications
    await db.execute('''
      CREATE TABLE ${YStrings.notifications} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colType} TEXT,
        ${YStrings.colItemId} TEXT,
        ${YStrings.colCount} INTEGER,
        ${YStrings.colWarehouseId} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colUpdatedAt} TEXT,
        ${YStrings.colSyncedAt} TEXT,
        FOREIGN KEY (${YStrings.colItemId}) REFERENCES ${YStrings.items} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colWarehouseId}) REFERENCES ${YStrings.warehouses} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Sync Metadata
    await db.execute('''
      CREATE TABLE ${YStrings.syncMetadata} (
        ${YStrings.colEntity} TEXT PRIMARY KEY,
        ${YStrings.colLastLocalUpdatedAt} TEXT,
        ${YStrings.colLastRemoteUpdatedAt} TEXT
      );
    ''');

    await _insertInitialSyncMetadataWithDb(db);
  }

  Future<void> _insertInitialSyncMetadataWithDb(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final table in [
      YStrings.locations,
      YStrings.warehouses,
      YStrings.items,
      YStrings.notifications,
    ]) {
      batch.insert(YStrings.syncMetadata, {
        YStrings.colEntity: table,
        YStrings.colLastLocalUpdatedAt: now,
        YStrings.colLastRemoteUpdatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> insertInitialSyncMetadata() async {
    final db = await database;
    await _insertInitialSyncMetadataWithDb(db);
  }

  // ================== Items ==================
  @override
  Future<void> insertItems(List<ItemModel> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      final map = item.toMap();
      map[YStrings.colSyncedAt] = map[YStrings.colSyncedAt] ?? null;
      batch.insert(
        YStrings.items,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<ItemModel>> getUnsyncedItems() async {
    final db = await database;
    final maps = await db.query(
      YStrings.items,
      where: '${YStrings.colSyncedAt} IS NULL',
    );
    return maps.map(ItemModel.fromDb).toList();
  }

  @override
  Future<void> markItemsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        YStrings.items,
        {YStrings.colSyncedAt: now},
        where: '${YStrings.colId} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<ItemModel>> getItemsByWarehouseId(String warehouseId) async {
    final db = await database;
    final maps = await db.query(
      YStrings.items,
      where: '${YStrings.colWarehouseId} = ?',
      whereArgs: [warehouseId],
    );
    return maps.map(ItemModel.fromDb).toList();
  }

  @override
  Future<bool> isItemsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.items} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearItems() async {
    final db = await database;
    await db.delete(YStrings.items);
  }

  // ================== Locations ==================
  @override
  Future<void> insertLocations(List<LocationModel> locations) async {
    final db = await database;
    final batch = db.batch();
    for (final loc in locations) {
      batch.insert(
        YStrings.locations,
        loc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<LocationModel>> getLocations() async {
    final db = await database;
    final maps = await db.query(YStrings.locations);
    return maps.map(LocationModel.fromDb).toList();
  }

  @override
  Future<bool> isLocationsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.locations} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearLocations() async {
    final db = await database;
    await db.delete(YStrings.locations);
  }

  // ================== Warehouses ==================
  @override
  Future<void> insertWarehouses(List<WarehouseModel> warehouses) async {
    final db = await database;
    final batch = db.batch();
    for (final w in warehouses) {
      batch.insert(
        YStrings.warehouses,
        w.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<WarehouseModel>> getWarehousesByLocationId(
    String locationId,
  ) async {
    final db = await database;
    final maps = await db.query(
      YStrings.warehouses,
      where: '${YStrings.colLocationId} = ?',
      whereArgs: [locationId],
    );
    return maps.map(WarehouseModel.fromDb).toList();
  }

  @override
  Future<bool> isWarehousesTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.warehouses} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearWarehouses() async {
    final db = await database;
    await db.delete(YStrings.warehouses);
  }

  // ================== Notifications ==================
  @override
  Future<List<NotificationModel>> getNotifications() async {
    final db = await database;
    final maps = await db.query(
      YStrings.notifications,
      orderBy: '${YStrings.colUpdatedAt} DESC',
    );
    return maps.map(NotificationModel.fromDb).toList();
  }

  @override
  Future<void> insertNotifications(
    List<NotificationModel> notifications,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final n in notifications) {
      final map = n.toMap();
      map[YStrings.colSyncedAt] = map[YStrings.colSyncedAt] ?? null;
      batch.insert(
        YStrings.notifications,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<NotificationModel>> getUnsyncedNotifications() async {
    final db = await database;
    final maps = await db.query(
      YStrings.notifications,
      where: '${YStrings.colSyncedAt} IS NULL',
    );
    return maps.map(NotificationModel.fromDb).toList();
  }

  @override
  Future<void> markNotificationsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        YStrings.notifications,
        {YStrings.colSyncedAt: now},
        where: '${YStrings.colId} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<bool> isNotificationsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.notifications} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete(YStrings.notifications);
  }

  // ================== Sync Metadata ==================
  @override
  Future<void> updateLastLocalUpdatedAt({
    required String entity,
    required String lastLocalUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      YStrings.syncMetadata,
      {YStrings.colLastLocalUpdatedAt: lastLocalUpdatedAt},
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
  }

  @override
  Future<void> updateLastRemoteUpdatedAt({
    required String entity,
    required String lastRemoteUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      YStrings.syncMetadata,
      {YStrings.colLastRemoteUpdatedAt: lastRemoteUpdatedAt},
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
  }

  @override
  Future<void> updateBothLocalAndRemoteTimestamps({
    required String entity,
    required String updatedAt,
  }) async {
    final db = await database;
    await db.update(
      YStrings.syncMetadata,
      {
        YStrings.colLastLocalUpdatedAt: updatedAt,
        YStrings.colLastRemoteUpdatedAt: updatedAt,
      },
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
  }

  @override
  Future<SyncMetadataModel?> getSyncMetadata(String entity) async {
    final db = await database;
    final result = await db.query(
      YStrings.syncMetadata,
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
    if (result.isNotEmpty) {
      return SyncMetadataModel.fromDb(result.first);
    }
    return null;
  }

  @override
  Future<bool> isSyncMetadataTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.syncMetadata} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearSyncMetadata() async {
    final db = await database;
    await db.delete(YStrings.syncMetadata);
  }

  @override
  Future<void> updateLocationsSync(String lastUpdatedAt) =>
      updateBothLocalAndRemoteTimestamps(
        entity: YStrings.locations,
        updatedAt: lastUpdatedAt,
      );

  @override
  Future<void> updateWarehousesSync(String lastUpdatedAt) =>
      updateBothLocalAndRemoteTimestamps(
        entity: YStrings.warehouses,
        updatedAt: lastUpdatedAt,
      );

  @override
  Future<void> updateItemsSync(String lastUpdatedAt) =>
      updateBothLocalAndRemoteTimestamps(
        entity: YStrings.items,
        updatedAt: lastUpdatedAt,
      );

  @override
  Future<void> updateNotificationsSync(String lastUpdatedAt) =>
      updateBothLocalAndRemoteTimestamps(
        entity: YStrings.notifications,
        updatedAt: lastUpdatedAt,
      );

  @override
  Future<Map<String, SyncMetadataModel>> getAllSyncMetadata() async {
    final db = await database;
    final rows = await db.query(YStrings.syncMetadata);
    return {
      for (final row in rows)
        row[YStrings.colEntity] as String: SyncMetadataModel.fromDb(row),
    };
  }

  @override
  Future<void> insertOrUpdateTable(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    if (data.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in data) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
