import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/db_helper.dart';
import '../../core/services/firebase_service.dart';
import '../../data/models/operation.dart';

enum SyncCollection { items, operations }

enum SyncStatus { waiting, syncing, success, failed }

class SyncController extends GetxController {
  final FirebaseService firebaseService = FirebaseService();

  var isSyncing = false.obs;
  var syncStatus = ''.obs;

  var collectionStatus = {
    SyncCollection.items: SyncStatus.waiting,
    SyncCollection.operations: SyncStatus.waiting,
  }.obs;

  var failedErrors = {
    SyncCollection.items: '',
    SyncCollection.operations: '',
  }.obs;

  Future<void> runSync() async {
    isSyncing.value = true;
    syncStatus.value = "Starting sync...";
    failedErrors[SyncCollection.items] = '';
    failedErrors[SyncCollection.operations] = '';
    collectionStatus[SyncCollection.items] = SyncStatus.syncing;
    collectionStatus[SyncCollection.operations] = SyncStatus.waiting;

    try {
      final db = await DBHelper.initDB();

      // Sync Items
      syncStatus.value = "Syncing items...";
      try {
        await _syncItems(db);
        collectionStatus[SyncCollection.items] = SyncStatus.success;
      } catch (e) {
        collectionStatus[SyncCollection.items] = SyncStatus.failed;
        failedErrors[SyncCollection.items] = e.toString();
        throw e;
      }

      // Sync Operations (only if items succeeded)
      syncStatus.value = "Syncing operations...";
      collectionStatus[SyncCollection.operations] = SyncStatus.syncing;
      try {
        await _syncOperations(db);
        collectionStatus[SyncCollection.operations] = SyncStatus.success;
      } catch (e) {
        collectionStatus[SyncCollection.operations] = SyncStatus.failed;
        failedErrors[SyncCollection.operations] = e.toString();
        throw e;
      }

      // Save sync info in DB
      await db.insert('sync_info', {
        "lastSyncTime": DateTime.now().toIso8601String(),
        "lastSyncStatus": "success",
      });

      syncStatus.value = "Sync completed successfully";
    } catch (e) {
      syncStatus.value = "Sync completed with errors";
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _syncItems(Database db) async {
    final firebaseItems = await firebaseService.fetchItems();
    for (final item in firebaseItems) {
      final local = await db.query(
        'items',
        where: 'id=?',
        whereArgs: [item.id],
      );

      if (local.isEmpty) {
        await db.insert('items', {
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'lastFirebaseModified': item.lastFirebaseModified.toIso8601String(),
          'lastLocalUpdate': DateTime.now().toIso8601String(),
        });
      } else {
        await db.update(
          'items',
          {
            'name': item.name,
            'quantity': item.quantity,
            'lastFirebaseModified': item.lastFirebaseModified.toIso8601String(),
            'lastLocalUpdate': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [item.id],
        );
      }
    }
  }

  Future<void> _syncOperations(Database db) async {
    final unsyncedOps = await db.query(
      'operations',
      where: 'status=?',
      whereArgs: ['pending'],
    );

    for (final row in unsyncedOps) {
      final op = Operation(
        uuid: row['uuid'] as String,
        itemId: row['itemId'] as String,
        itemName: row['itemName'] as String,
        type: row['type'] == 'import'
            ? OperationType.import
            : OperationType.export,
        quantity: row['quantity'] as int,
        localPerformedAt: DateTime.parse(row['localPerformedAt'] as String),
      );

      try {
        final firebaseItem = await firebaseService.getItemById(op.itemId);

        if (op.type == OperationType.import) {
          firebaseItem.quantity += op.quantity;
        } else {
          firebaseItem.quantity -= op.quantity;
        }

        await firebaseService.updateItem(firebaseItem);

        op.serverSyncedAt = DateTime.now();
        op.status = OperationStatus.synced;
        await firebaseService.addOperation(op);

        await db.update(
          'operations',
          {
            'status': 'synced',
            'serverSyncedAt': op.serverSyncedAt!.toIso8601String(),
          },
          where: 'uuid=?',
          whereArgs: [op.uuid],
        );

        await db.update(
          'items',
          {
            'quantity': firebaseItem.quantity,
            'lastLocalUpdate': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [firebaseItem.id],
        );
      } catch (e) {
        throw e;
      }
    }
  }
}
