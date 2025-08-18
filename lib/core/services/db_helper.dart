import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> initDB() async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'warehouse.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items(
            id TEXT PRIMARY KEY,
            name TEXT,
            quantity INTEGER,
            lastFirebaseModified TEXT,
            lastLocalUpdate TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE operations(
            uuid TEXT PRIMARY KEY,
            itemId TEXT,
            itemName TEXT,
            type TEXT,
            quantity INTEGER,
            localPerformedAt TEXT,
            serverSyncedAt TEXT,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_info(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lastSyncTime TEXT,
            lastSyncStatus TEXT
          )
        ''');
      },
    );
    return _db!;
  }
}
