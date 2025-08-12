import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class NotificationListController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;
  final ConnectivityClient connectivityClient;
  final SharedPreferences prefs;

  NotificationListController({
    required this.dbClient,
    required this.firebaseClient,
    required this.connectivityClient,
    required this.prefs,
  });

  var notifications = <NotificationModel>[].obs;
  var isSyncing = false.obs;

  final itemNameCache = <String, String>{}.obs;
  final warehouseNameCache = <String, String>{}.obs;
  final locationNameCache = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final notifModels = await dbClient.getNotifications();

    notifModels.sort((a, b) {
      final aSynced = a.syncedAt != null;
      final bSynced = b.syncedAt != null;
      if (aSynced != bSynced) return aSynced ? 1 : -1;
      return DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt));
    });

    for (final notif in notifModels) {
      if (!warehouseNameCache.containsKey(notif.warehouseId)) {
        warehouseNameCache[notif.warehouseId] = await _getWarehouseName(
          notif.warehouseId,
        );
      }
      if (!locationNameCache.containsKey(notif.locationId)) {
        locationNameCache[notif.locationId] = await _getLocationName(
          notif.locationId,
        );
      }
      if (!itemNameCache.containsKey(notif.itemId)) {
        itemNameCache[notif.itemId] = await _getItemName(notif.itemId);
      }
    }

    notifications.value = notifModels;
  }

  Future<void> syncUnsyncedData() async {
    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      _showToast(
        "No internet connection. Please try again later.",
        isError: true,
      );
      return;
    }

    final unsyncedItems = await dbClient.getUnsyncedItems();
    final unsyncedNotifs = await dbClient.getUnsyncedNotifications();

    if (unsyncedItems.isEmpty && unsyncedNotifs.isEmpty) {
      _showToast("Already synced");
      return;
    }

    isSyncing.value = true;
    bool allSuccess = true;

    try {
      for (final item in unsyncedItems) {
        try {
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', true);
        } catch (e) {
          allSuccess = false;
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', false);
          _showToast("Failed to sync item: ${e.toString()}", isError: true);
          return;
        }
      }

      for (final notif in unsyncedNotifs) {
        try {
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
          prefs.setBool(
            '${YStrings.syncStatusPrefix}${YStrings.notifications}',
            true,
          );
        } catch (e) {
          allSuccess = false;
          prefs.setBool(
            '${YStrings.syncStatusPrefix}${YStrings.notifications}',
            false,
          );
          _showToast(
            "Notification ${notif.id} failed to sync: $e",
            isError: true,
          );
          return;
        }
      }

      final now = DateTime.now();

      try {
        await firebaseClient.updateSyncMetadata(
          entity: YStrings.items,
          lastTableUpdatedAt: now,
        );
        await firebaseClient.updateSyncMetadata(
          entity: YStrings.notifications,
          lastTableUpdatedAt: now,
        );
      } catch (e) {
        debugPrint(
          "[NotificationListController] Remote metadata update failed: $e",
        );
      }

      await dbClient.updateBothLocalAndRemoteTimestamps(
        entity: YStrings.items,
        updatedAt: now.toIso8601String(),
      );
      await dbClient.updateBothLocalAndRemoteTimestamps(
        entity: YStrings.notifications,
        updatedAt: now.toIso8601String(),
      );

      prefs.setBool(YStrings.lastInitSyncSuccess, allSuccess);

      if (allSuccess) {
        _showToast("Data synced successfully");
      }

      await fetchNotifications();
    } finally {
      isSyncing.value = false;
    }
  }

  Future<String> _getItemName(String itemId) async {
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.items,
      where: '${YStrings.colId} = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first[YStrings.colName] as String;
    }
    return itemId;
  }

  Future<String> _getWarehouseName(String warehouseId) async {
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.warehouses,
      where: '${YStrings.colId} = ?',
      whereArgs: [warehouseId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first[YStrings.colName] as String;
    }
    return warehouseId;
  }

  Future<String> _getLocationName(String locationId) async {
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.locations,
      where: '${YStrings.colId} = ?',
      whereArgs: [locationId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first[YStrings.colName] as String;
    }
    return locationId;
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
