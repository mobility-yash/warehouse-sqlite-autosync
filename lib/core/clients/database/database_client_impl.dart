import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';

import 'db_mixins/items_db_mixin.dart';
import 'db_mixins/locations_db_mixin.dart';
import 'db_mixins/notifications_db_mixin.dart';
import 'db_mixins/sync_metadata_db_mixin.dart';
import 'db_mixins/warehouses_db_mixin.dart';

class DatabaseClientImpl extends DatabaseClient
    with
        ItemsDbMixin,
        LocationsDbMixin,
        NotificationsDbMixin,
        SyncMetadataDbMixin,
        WarehousesDbMixin {
  static const _dbName = 'app_data.db';
  static const _dbVersion = 1;

  Database? _database;

  DatabaseClientImpl();

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    return _database = await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

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

    await insertInitialSyncMetadata();
  }
}
