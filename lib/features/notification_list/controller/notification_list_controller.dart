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
    debugPrint(
      "Yash [NotificationListController] [onInit] - Controller initialized",
    );
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    debugPrint(
      "Yash [NotificationListController] [fetchNotifications] - Fetching notifications",
    );
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
    debugPrint(
      "Yash [NotificationListController] [fetchNotifications] - Loaded ${notifications.length} notifications",
    );
  }

  Future<void> syncUnsyncedData() async {
    debugPrint(
      "Yash [NotificationListController] [syncUnsyncedData] - Starting sync",
    );
    final hasNetwork = await connectivityClient.getSmartStatus();
    debugPrint(
      "Yash [NotificationListController] [syncUnsyncedData] - Network status: $hasNetwork",
    );
    if (!hasNetwork) {
      _showToast(
        "No internet connection. Please try again later.",
        isError: true,
      );
      debugPrint(
        "Yash [NotificationListController] [syncUnsyncedData] - No internet, aborting sync",
      );
      return;
    }

    final unsyncedItems = await dbClient.getUnsyncedItems();
    final unsyncedNotifs = await dbClient.getUnsyncedNotifications();
    debugPrint(
      "Yash [NotificationListController] [syncUnsyncedData] - Unsynced items: ${unsyncedItems.length}, notifications: ${unsyncedNotifs.length}",
    );

    if (unsyncedItems.isEmpty && unsyncedNotifs.isEmpty) {
      _showToast("Already synced");
      debugPrint(
        "Yash [NotificationListController] [syncUnsyncedData] - Nothing to sync",
      );
      return;
    }

    isSyncing.value = true;
    bool allSuccess = true;

    try {
      for (final item in unsyncedItems) {
        try {
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Syncing item: ${item.id}",
          );
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', true);
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Item synced: ${item.id}",
          );
        } catch (e) {
          allSuccess = false;
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', false);
          _showToast("Failed to sync item: ${e.toString()}", isError: true);
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Failed to sync item ${item.id}: $e",
          );
          return;
        }
      }

      for (final notif in unsyncedNotifs) {
        try {
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Syncing notification: ${notif.id}",
          );
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
          prefs.setBool(
            '${YStrings.syncStatusPrefix}${YStrings.notifications}',
            true,
          );
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Notification synced: ${notif.id}",
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
          debugPrint(
            "Yash [NotificationListController] [syncUnsyncedData] - Failed to sync notification ${notif.id}: $e",
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
        debugPrint(
          "Yash [NotificationListController] [syncUnsyncedData] - Remote sync metadata updated",
        );
      } catch (e) {
        debugPrint(
          "Yash [NotificationListController] [syncUnsyncedData] - Remote metadata update failed: $e",
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
        debugPrint(
          "Yash [NotificationListController] [syncUnsyncedData] - Sync completed successfully",
        );
      }

      await fetchNotifications();
    } finally {
      isSyncing.value = false;
      debugPrint(
        "Yash [NotificationListController] [syncUnsyncedData] - Sync process finished",
      );
    }
  }

  Future<String> _getItemName(String itemId) async {
    debugPrint(
      "Yash [NotificationListController] [_getItemName] - Fetching name for itemId: $itemId",
    );
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.items,
      where: '${YStrings.colId} = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      debugPrint(
        "Yash [NotificationListController] [_getItemName] - Found item name: ${res.first[YStrings.colName]}",
      );
      return res.first[YStrings.colName] as String;
    }
    debugPrint(
      "Yash [NotificationListController] [_getItemName] - Item name not found, returning id",
    );
    return itemId;
  }

  Future<String> _getWarehouseName(String warehouseId) async {
    debugPrint(
      "Yash [NotificationListController] [_getWarehouseName] - Fetching name for warehouseId: $warehouseId",
    );
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.warehouses,
      where: '${YStrings.colId} = ?',
      whereArgs: [warehouseId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      debugPrint(
        "Yash [NotificationListController] [_getWarehouseName] - Found warehouse name: ${res.first[YStrings.colName]}",
      );
      return res.first[YStrings.colName] as String;
    }
    debugPrint(
      "Yash [NotificationListController] [_getWarehouseName] - Warehouse name not found, returning id",
    );
    return warehouseId;
  }

  Future<String> _getLocationName(String locationId) async {
    debugPrint(
      "Yash [NotificationListController] [_getLocationName] - Fetching name for locationId: $locationId",
    );
    final db = await dbClient.database;
    final res = await db.query(
      YStrings.locations,
      where: '${YStrings.colId} = ?',
      whereArgs: [locationId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      debugPrint(
        "Yash [NotificationListController] [_getLocationName] - Found location name: ${res.first[YStrings.colName]}",
      );
      return res.first[YStrings.colName] as String;
    }
    debugPrint(
      "Yash [NotificationListController] [_getLocationName] - Location name not found, returning id",
    );
    return locationId;
  }

  void _showToast(String message, {bool isError = false}) {
    debugPrint(
      "Yash [NotificationListController] [_showToast] - ${isError ? 'ERROR' : 'INFO'}: $message",
    );
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
