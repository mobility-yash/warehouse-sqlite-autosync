import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';

mixin NotificationsDbMixin on DatabaseClient {
  @override
  Future<void> insertNotifications(
    List<NotificationModel> notifications,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final notification in notifications) {
      batch.insert(
        'notifications',
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<NotificationModel>> getUnsyncedNotifications() async {
    final db = await database;
    final maps = await db.query(
      'notifications',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => NotificationModel.fromDb(map)).toList();
  }

  @override
  Future<void> markNotificationsAsSynced(List<String> ids) async {
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
  }

  @override
  Future<bool> isNotificationsTableNotEmpty() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM notifications LIMIT 1)',
    );
    return Sqflite.firstIntValue(result) == 1;
  }

  @override
  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete('notifications');
  }
}
