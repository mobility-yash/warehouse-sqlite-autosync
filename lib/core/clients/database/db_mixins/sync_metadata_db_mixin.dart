import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/sync_metadata_model.dart';

mixin SyncMetadataDbMixin on DatabaseClient {
  // Insert fixed initial rows
  @override
  Future<void> insertInitialSyncMetadata() async {
    final db = await database;
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
  }

  // Update lastUpdatedAt for a specific entity
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
  }

  // Get sync metadata for a specific entity
  @override
  Future<SyncMetadataModel?> getSyncMetadata(String entity) async {
    final db = await database;
    final result = await db.query(
      'sync_metadata',
      where: 'entity = ?',
      whereArgs: [entity],
    );

    if (result.isNotEmpty) {
      return SyncMetadataModel.fromDb(result.first);
    }
    return null;
  }

  // Check if table has rows
  @override
  Future<bool> isSyncMetadataTableNotEmpty() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM sync_metadata LIMIT 1)',
    );
    return Sqflite.firstIntValue(result) == 1;
  }

  // Clear sync metadata table
  @override
  Future<void> clearSyncMetadata() async {
    final db = await database;
    await db.delete('sync_metadata');
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
