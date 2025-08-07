import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/location_model.dart';

mixin LocationsDbMixin on DatabaseClient {
  @override
  Future<void> insertLocations(List<LocationModel> locations) async {
    final db = await database;
    final batch = db.batch();

    for (final location in locations) {
      batch.insert(
        'locations',
        location.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<LocationModel>> getLocations() async {
    final db = await database;
    final maps = await db.query('locations');
    return maps.map((map) => LocationModel.fromDb(map)).toList();
  }

  @override
  Future<bool> isLocationsTableNotEmpty() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM locations LIMIT 1)',
    );
    return Sqflite.firstIntValue(result) == 1;
  }

  @override
  Future<void> clearLocations() async {
    final db = await database;
    await db.delete('locations');
  }
}
