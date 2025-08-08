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

class DatabaseClientImpl extends DatabaseClient {
  static const _dbName = 'app_data.db';
  static const _dbVersion = 1;

  Database? _database;
  Completer<Database>? _openingCompleter;

  DatabaseClientImpl();

  // -------------------------
  // Database getter + init
  // -------------------------
  @override
  Future<Database> get database async {
    if (_database != null) {
      debugPrint('[DatabaseClientImpl] Reusing existing database instance.');
      return _database!;
    }

    // If already opening, wait for the same future instead of starting another open
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
      // allow future open attempts to create a new completer if needed
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

  // -------------------------
  // onCreate (use provided `db` - do NOT call `database` here)
  // -------------------------
  Future<void> _onCreate(Database db, int version) async {
    // Locations table
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        name TEXT,
        address TEXT,
        updatedAt TEXT
      );
    ''');

    // Warehouses table
    await db.execute('''
      CREATE TABLE warehouses (
        id TEXT PRIMARY KEY,
        name TEXT,
        locationId TEXT,
        address TEXT,
        updatedAt TEXT,
        FOREIGN KEY (locationId) REFERENCES locations (id)
      );
    ''');

    // Items table
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT,
        warehouseId TEXT,
        locationId TEXT,
        quantity INTEGER,
        updatedAt TEXT,
        FOREIGN KEY (warehouseId) REFERENCES warehouses (id),
        FOREIGN KEY (locationId) REFERENCES locations (id)
      );
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT,
        itemId TEXT,
        count INTEGER,
        warehouseId TEXT,
        locationId TEXT,
        updatedAt TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (itemId) REFERENCES items (id),
        FOREIGN KEY (warehouseId) REFERENCES warehouses (id),
        FOREIGN KEY (locationId) REFERENCES locations (id)
      );
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        entity TEXT PRIMARY KEY,
        lastUpdatedAt TEXT
      );
    ''');

    // Insert initial metadata using the `db` instance (avoid calling `database` here)
    await _insertInitialSyncMetadataWithDb(db);
  }

  // -------------------------
  // Helper to insert initial sync metadata during onCreate (uses provided db)
  // -------------------------
  Future<void> _insertInitialSyncMetadataWithDb(Database db) async {
    final batch = db.batch();

    batch.insert('sync_metadata', {
      'entity': 'locations',
      'lastUpdatedAt': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('sync_metadata', {
      'entity': 'warehouses',
      'lastUpdatedAt': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('sync_metadata', {
      'entity': 'items',
      'lastUpdatedAt': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('sync_metadata', {
      'entity': 'notifications',
      'lastUpdatedAt': '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
    debugPrint(
      '[DatabaseClientImpl] Initial sync_metadata inserted (onCreate).',
    );
  }

  // -------------------------
  // Public insertInitialSyncMetadata (calls the helper using the opened DB)
  // -------------------------
  @override
  Future<void> insertInitialSyncMetadata() async {
    final db = await database;
    await _insertInitialSyncMetadataWithDb(db);
  }

  // -------------------------
  // Items
  // -------------------------
  @override
  Future<void> insertItems(List<ItemModel> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'items',
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
      'items',
      where: 'warehouseId = ?',
      whereArgs: [warehouseId],
    );
    debugPrint(
      '[DatabaseClientImpl] getItemsByWarehouseId: found ${maps.length}',
    );
    return maps.map((m) => ItemModel.fromDb(m)).toList();
  }

  @override
  Future<bool> isItemsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM items LIMIT 1)',
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
    await db.delete('items');
    debugPrint('[DatabaseClientImpl] Cleared items table.');
  }

  // -------------------------
  // Locations
  // -------------------------
  @override
  Future<void> insertLocations(List<LocationModel> locations) async {
    final db = await database;
    final batch = db.batch();
    for (final loc in locations) {
      batch.insert(
        'locations',
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
    final maps = await db.query('locations');
    debugPrint('[DatabaseClientImpl] getLocations: found ${maps.length}');
    return maps.map((m) => LocationModel.fromDb(m)).toList();
  }

  @override
  Future<bool> isLocationsTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM locations LIMIT 1)',
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
    await db.delete('locations');
    debugPrint('[DatabaseClientImpl] Cleared locations table.');
  }

  // -------------------------
  // Warehouses
  // -------------------------
  @override
  Future<void> insertWarehouses(List<WarehouseModel> warehouses) async {
    final db = await database;
    final batch = db.batch();
    for (final w in warehouses) {
      batch.insert(
        'warehouses',
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
      'warehouses',
      where: 'locationId = ?',
      whereArgs: [locationId],
    );
    debugPrint(
      '[DatabaseClientImpl] getWarehousesByLocationId: found ${maps.length}',
    );
    return maps.map((m) => WarehouseModel.fromDb(m)).toList();
  }

  @override
  Future<bool> isWarehousesTableNotEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM warehouses LIMIT 1)',
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
    await db.delete('warehouses');
    debugPrint('[DatabaseClientImpl] Cleared warehouses table.');
  }

  // -------------------------
  // Notifications
  // -------------------------
  @override
  Future<void> insertNotifications(
    List<NotificationModel> notifications,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final n in notifications) {
      batch.insert(
        'notifications',
        n.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    debugPrint(
      '[DatabaseClientImpl] Inserted ${notifications.length} notifications.',
    );
  }

  @override
  Future<List<NotificationModel>> getUnsyncedNotifications() async {
    final db = await database;
    final maps = await db.query(
      'notifications',
      where: 'synced = ?',
      whereArgs: [0],
    );
    debugPrint(
      '[DatabaseClientImpl] getUnsyncedNotifications: found ${maps.length}',
    );
    return maps.map((m) => NotificationModel.fromDb(m)).toList();
  }

  @override
  Future<void> markNotificationsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'notifications',
        {'synced': 1},
        where: 'id = ?',
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
        'SELECT EXISTS(SELECT 1 FROM notifications LIMIT 1)',
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
    await db.delete('notifications');
    debugPrint('[DatabaseClientImpl] Cleared notifications table.');
  }

  // -------------------------
  // Sync metadata
  // -------------------------
  @override
  Future<void> updateLastUpdatedAt({
    required String entity,
    required String lastUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      'sync_metadata',
      {'lastUpdatedAt': lastUpdatedAt},
      where: 'entity = ?',
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
      'sync_metadata',
      where: 'entity = ?',
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
        'SELECT EXISTS(SELECT 1 FROM sync_metadata LIMIT 1)',
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
    await db.delete('sync_metadata');
    debugPrint('[DatabaseClientImpl] Cleared sync_metadata table.');
  }

  @override
  Future<void> updateLocationsSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(entity: 'locations', lastUpdatedAt: lastUpdatedAt);

  @override
  Future<void> updateWarehousesSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(entity: 'warehouses', lastUpdatedAt: lastUpdatedAt);

  @override
  Future<void> updateItemsSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(entity: 'items', lastUpdatedAt: lastUpdatedAt);

  @override
  Future<void> updateNotificationsSync(String lastUpdatedAt) =>
      updateLastUpdatedAt(
        entity: 'notifications',
        lastUpdatedAt: lastUpdatedAt,
      );
}
