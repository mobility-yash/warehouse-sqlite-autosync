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
    debugPrint("[NotificationListController] onInit() called");
    super.onInit();
    fetchNotifications();
  }

  /// Fetch notifications and preload warehouse/location names
  Future<void> fetchNotifications() async {
    debugPrint("[NotificationListController] Fetching notifications...");
    final notifModels = await dbClient.getNotifications();

    notifModels.sort((a, b) {
      if (a.synced != b.synced) return a.synced ? 1 : -1;
      return DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt));
    });

    // Cache names
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
      "[NotificationListController] Updated list with ${notifications.length} notifications",
    );
  }

  /// Sync data with Firebase
  Future<void> syncUnsyncedData() async {
    debugPrint("[NotificationListController] syncUnsyncedData started");

    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      debugPrint("[NotificationListController] No network connection");
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
      debugPrint("[NotificationListController] Already synced — no action");
      return;
    }

    isSyncing.value = true;
    bool allSuccess = true;

    try {
      // ==== Sync Items ====
      for (final item in unsyncedItems) {
        try {
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', true);
          debugPrint("[NotificationListController] Synced item: ${item.id}");
        } catch (e) {
          allSuccess = false;
          prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', false);
          debugPrint("[NotificationListController] Item ${item.id} failed: $e");
          _showToast("Failed to sync item: ${e.toString()}", isError: true);
          return;
        }
      }

      // ==== Sync Notifications ====
      for (final notif in unsyncedNotifs) {
        try {
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
          prefs.setBool(
            '${YStrings.syncStatusPrefix}${YStrings.notifications}',
            true,
          );
          debugPrint(
            "[NotificationListController] Synced notification: ${notif.id}",
          );
        } catch (e) {
          allSuccess = false;
          prefs.setBool(
            '${YStrings.syncStatusPrefix}${YStrings.notifications}',
            false,
          );
          final errorMsg = "Notification ${notif.id} failed to sync: $e";
          debugPrint("[NotificationListController] $errorMsg");
          _showToast(errorMsg, isError: true);
          return;
        }
      }

      final now = DateTime.now();

      try {
        await firebaseClient.updateSyncMetadata(YStrings.items, now);
        await firebaseClient.updateSyncMetadata(YStrings.notifications, now);
      } catch (e) {
        debugPrint(
          "[NotificationListController] Remote metadata update failed: $e",
        );
      }

      await dbClient.updateSyncMetadata(YStrings.items, now);
      await dbClient.updateSyncMetadata(YStrings.notifications, now);

      prefs.setBool(YStrings.lastInitSyncSuccess, allSuccess);

      if (allSuccess) {
        _showToast("Data synced successfully");
      }

      await fetchNotifications();
    } finally {
      isSyncing.value = false;
      debugPrint("[NotificationListController] syncUnsyncedData complete");
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

  /// Get readable warehouse name from DB
  Future<String> _getWarehouseName(String warehouseId) async {
    // You can add DatabaseClient.getWarehouseNameById for more efficiency
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
    return warehouseId; // fallback to ID
  }

  /// Get readable location name from DB
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
    return locationId; // fallback to ID
  }

  /// Show toast helper
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
