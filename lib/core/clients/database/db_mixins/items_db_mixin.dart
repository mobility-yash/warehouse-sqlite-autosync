import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';

mixin ItemsDbMixin on DatabaseClient {
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
  }

  @override
  Future<List<ItemModel>> getItemsByWarehouseId(String warehouseId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'warehouseId = ?',
      whereArgs: [warehouseId],
    );
    return maps.map((map) => ItemModel.fromDb(map)).toList();
  }

  @override
  Future<bool> isItemsTableNotEmpty() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM items LIMIT 1)',
    );
    return Sqflite.firstIntValue(result) == 1;
  }

  @override
  Future<void> clearItems() async {
    final db = await database;
    await db.delete('items');
  }
}
