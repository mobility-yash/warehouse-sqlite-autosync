import 'dart:async';

import 'package:flutter/material.dart';
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
    if (_database != null) {
      debugPrint('[DatabaseClientImpl] Reusing existing database instance.');
      return _database!;
    }

    if (_openingCompleter != null) {
      debugPrint(
        '[DatabaseClientImpl] Waiting for database to finish opening...',
      );
      return _openingCompleter!.future;
    }

    _openingCompleter = Completer();
    debugPrint('[DatabaseClientImpl] Database not initialized. Opening now...');

    try {
      final db = await _initDatabase();
      _database = db;
      _openingCompleter!.complete(db);
      debugPrint('[DatabaseClientImpl] Database opened successfully.');
      return db;
    } catch (e, stack) {
      _openingCompleter!.completeError(e, stack);
      rethrow;
    } finally {
      _openingCompleter = null;
    }
  }

  Future<Database> _initDatabase() async {
    debugPrint('[DatabaseClientImpl] Initializing database...');
    final dbPath = await getDatabasesPath();
    debugPrint('[DatabaseClientImpl] Database path: $dbPath');

    final path = join(dbPath, _dbName);
    debugPrint('[DatabaseClientImpl] Full database file path: $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        debugPrint(
          '[DatabaseClientImpl] onCreate called. Creating tables for version: $version',
        );
        await _onCreate(db, version);
        debugPrint('[DatabaseClientImpl] All tables created successfully.');
      },
      onOpen: (db) {
        debugPrint('[DatabaseClientImpl] Database opened (onOpen callback).');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Locations table
    await db.execute('''
      CREATE TABLE ${YStrings.locations} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colAddress} TEXT,
        ${YStrings.colUpdatedAt} TEXT
      );
    ''');

    // Warehouses table
    await db.execute('''
      CREATE TABLE ${YStrings.warehouses} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colAddress} TEXT,
        ${YStrings.colUpdatedAt} TEXT,
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Items table
    await db.execute('''
      CREATE TABLE ${YStrings.items} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colName} TEXT,
        ${YStrings.colWarehouseId} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colQuantity} INTEGER,
        ${YStrings.colUpdatedAt} TEXT,
        FOREIGN KEY (${YStrings.colWarehouseId}) REFERENCES ${YStrings.warehouses} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE ${YStrings.notifications} (
        ${YStrings.colId} TEXT PRIMARY KEY,
        ${YStrings.colType} TEXT,
        ${YStrings.colItemId} TEXT,
        ${YStrings.colCount} INTEGER,
        ${YStrings.colWarehouseId} TEXT,
        ${YStrings.colLocationId} TEXT,
        ${YStrings.colUpdatedAt} TEXT,
        ${YStrings.colSynced} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${YStrings.colItemId}) REFERENCES ${YStrings.items} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colWarehouseId}) REFERENCES ${YStrings.warehouses} (${YStrings.colId}),
        FOREIGN KEY (${YStrings.colLocationId}) REFERENCES ${YStrings.locations} (${YStrings.colId})
      );
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE ${YStrings.syncMetadata} (
        ${YStrings.colEntity} TEXT PRIMARY KEY,
        ${YStrings.colLastUpdatedAt} TEXT
      );
    ''');

    await _insertInitialSyncMetadataWithDb(db);
  }

  Future<void> _insertInitialSyncMetadataWithDb(Database db) async {
    final batch = db.batch();
    for (final table in [
      YStrings.locations,
      YStrings.warehouses,
      YStrings.items,
      YStrings.notifications,
    ]) {
      batch.insert(YStrings.syncMetadata, {
        YStrings.colEntity: table,
        YStrings.colLastUpdatedAt: '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint('[DatabaseClientImpl] Initial sync_metadata inserted.');
  }

  @override
  Future<void> insertInitialSyncMetadata() async {
    final db = await database;
    await _insertInitialSyncMetadataWithDb(db);
  }

  // Items
  @override
  Future<void> insertItems(List<ItemModel> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        YStrings.items,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    debugPrint('[DatabaseClientImpl] Inserted ${items.length} items.');
  }

  @override
  Future<List<ItemModel>> getItemsByWarehouseId(String warehouseId) async {
    final db = await database;
    final maps = await db.query(
      YStrings.items,
      where: '${YStrings.colWarehouseId} = ?',
      whereArgs: [warehouseId],
    );
    debugPrint(
      '[DatabaseClientImpl] getItemsByWarehouseId: found ${maps.length}',
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
    } catch (e, st) {
      debugPrint('[DatabaseClientImpl] ERROR in isItemsTableNotEmpty: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  @override
  Future<void> clearItems() async {
    final db = await database;
    await db.delete(YStrings.items);
    debugPrint('[DatabaseClientImpl] Cleared items table.');
  }

  // Locations
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
    debugPrint('[DatabaseClientImpl] Inserted ${locations.length} locations.');
  }

  @override
  Future<List<LocationModel>> getLocations() async {
    final db = await database;
    final maps = await db.query(YStrings.locations);
    debugPrint('[DatabaseClientImpl] getLocations: found ${maps.length}');
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
    } catch (e, st) {
      debugPrint('[DatabaseClientImpl] ERROR in isLocationsTableNotEmpty: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  @override
  Future<void> clearLocations() async {
    final db = await database;
    await db.delete(YStrings.locations);
    debugPrint('[DatabaseClientImpl] Cleared locations table.');
  }

  // Warehouses
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
    debugPrint(
      '[DatabaseClientImpl] Inserted ${warehouses.length} warehouses.',
    );
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
    debugPrint(
      '[DatabaseClientImpl] getWarehousesByLocationId: found ${maps.length}',
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
    } catch (e, st) {
      debugPrint('[DatabaseClientImpl] ERROR in isWarehousesTableNotEmpty: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  @override
  Future<void> clearWarehouses() async {
    final db = await database;
    await db.delete(YStrings.warehouses);
    debugPrint('[DatabaseClientImpl] Cleared warehouses table.');
  }

  // Notifications
  @override
  Future<void> insertNotifications(
    List<NotificationModel> notifications,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final n in notifications) {
      final map = n.toMap();
      map[YStrings.colSynced] = 1;
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
      where: '${YStrings.colSynced} = ?',
      whereArgs: [0],
    );
    debugPrint(
      '[DatabaseClientImpl] getUnsyncedNotifications: found ${maps.length}',
    );
    return maps.map(NotificationModel.fromDb).toList();
  }

  @override
  Future<void> markNotificationsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        YStrings.notifications,
        {YStrings.colSynced: 1},
        where: '${YStrings.colId} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    debugPrint(
      '[DatabaseClientImpl] Marked ${ids.length} notifications as synced.',
    );
  }

  @override
  Future<bool> isNotificationsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM ${YStrings.notifications} LIMIT 1)',
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (e, st) {
      debugPrint(
        '[DatabaseClientImpl] ERROR in isNotificationsTableNotEmpty: $e',
      );
      debugPrint(st.toString());
      return false;
    }
  }

  @override
  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete(YStrings.notifications);
  }

  // Sync metadata
  @override
  Future<void> updateLastUpdatedAt({
    required String entity,
    required String lastUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      YStrings.syncMetadata,
      {YStrings.colLastUpdatedAt: lastUpdatedAt},
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
    debugPrint(
      '[DatabaseClientImpl] updateLastUpdatedAt for $entity -> $lastUpdatedAt',
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
    if (result.isNotEmpty) return SyncMetadataModel.fromDb(result.first);
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
    } catch (e, st) {
      debugPrint(
        '[DatabaseClientImpl] ERROR in isSyncMetadataTableNotEmpty: $e',
      );
      debugPrint(st.toString());
      return false;
    }
  }

  @override
  Future<void> clearSyncMetadata() async {
    final db = await database;
    await db.delete(YStrings.syncMetadata);
    debugPrint('[DatabaseClientImpl] Cleared sync_metadata table.');
  }

  @override
  Future<void> updateLocationsSync(String lastUpdatedAt) => updateLastUpdatedAt(
    entity: YStrings.locations,
    lastUpdatedAt: lastUpdatedAt,
  );

  @override
  Future<void> updateWarehousesSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(
        entity: YStrings.warehouses,
        lastUpdatedAt: lastUpdatedAt,
      );

  @override
  Future<void> updateItemsSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(entity: YStrings.items, lastUpdatedAt: lastUpdatedAt);

  @override
  Future<void> updateNotificationsSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(
        entity: YStrings.notifications,
        lastUpdatedAt: lastUpdatedAt,
      );

  @override
  Future<Map<String, DateTime?>> getSyncMetadataMap() async {
    final db = await database;
    final rows = await db.query(YStrings.syncMetadata);
    final map = <String, DateTime?>{};
    for (final row in rows) {
      final entity = row[YStrings.colEntity] as String;
      final tsString = row[YStrings.colLastUpdatedAt] as String?;
      map[entity] = tsString != null ? DateTime.tryParse(tsString) : null;
    }
    debugPrint('[DatabaseClientImpl] getSyncMetadataMap -> $map');
    return map;
  }

  @override
  Future<void> insertOrUpdateTable(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    if (data.isEmpty) {
      debugPrint(
        '[DatabaseClientImpl] insertOrUpdateTable: No data for $table',
      );
      return;
    }

    final db = await database;
    final batch = db.batch();

    for (final row in data) {
      final rowCopy = Map<String, dynamic>.from(row);

      // Special handling for sync_metadata table
      if (table == YStrings.syncMetadata &&
          rowCopy.containsKey(YStrings.colUpdatedAt)) {
        rowCopy.remove(YStrings.colId);
        rowCopy[YStrings.colLastUpdatedAt] = rowCopy.remove(
          YStrings.colUpdatedAt,
        );
      }

      batch.insert(
        table,
        rowCopy,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    debugPrint(
      '[DatabaseClientImpl] insertOrUpdateTable: Upserted ${data.length} rows into $table',
    );
  }

  @override
  Future<void> updateSyncMetadata(
    String entity,
    DateTime? lastUpdatedAt,
  ) async {
    final db = await database;
    await db.update(
      YStrings.syncMetadata,
      {YStrings.colLastUpdatedAt: lastUpdatedAt?.toIso8601String()},
      where: '${YStrings.colEntity} = ?',
      whereArgs: [entity],
    );
    debugPrint(
      '[DatabaseClientImpl] updateSyncMetadata for $entity -> ${lastUpdatedAt?.toIso8601String() ?? "null"}',
    );
  }
}
