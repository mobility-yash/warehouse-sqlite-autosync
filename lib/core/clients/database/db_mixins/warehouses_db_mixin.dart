import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/warehouse_model.dart';

mixin WarehousesDbMixin on DatabaseClient {
  @override
  Future<void> insertWarehouses(List<WarehouseModel> warehouses) async {
    final db = await database;
    final batch = db.batch();

    for (final warehouse in warehouses) {
      batch.insert(
        'warehouses',
        warehouse.toMap(),
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
      'warehouses',
      where: 'locationId = ?',
      whereArgs: [locationId],
    );
    return maps.map((map) => WarehouseModel.fromDb(map)).toList();
  }

  @override
  Future<bool> isWarehousesTableNotEmpty() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM warehouses LIMIT 1)',
    );
    return Sqflite.firstIntValue(result) == 1;
  }

  @override
  Future<void> clearWarehouses() async {
    final db = await database;
    await db.delete('warehouses');
  }
}
