import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class NotificationListController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;
  final ConnectivityClient connectivityClient;

  NotificationListController({
    required this.dbClient,
    required this.firebaseClient,
    required this.connectivityClient,
  });

  var notifications = <NotificationModel>[].obs;
  var isSubmitting = false.obs;
  var isLoadingItems = false.obs;
  var isSyncing = false.obs;

  @override
  void onInit() {
    debugPrint("[NotificationListController] onInit() called");
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    debugPrint("[NotificationListController] Fetching notifications...");
    final notifModels = await dbClient.getNotifications();
    notifModels.sort((a, b) {
      if (a.synced != b.synced) return a.synced ? 1 : -1;
      return DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt));
    });
    notifications.value = notifModels;
    debugPrint(
      "[NotificationListController] Updated list with ${notifications.length} notifications",
    );
  }

  /// Push all unsynced items and notifications to Firestore and mark locally as synced.
  Future<void> syncUnsyncedData() async {
    debugPrint("[NotificationListController] syncUnsyncedData started");

    // Network check first
    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      debugPrint("[NotificationListController] No network connection");
      _showToast(
        "No internet connection. Please try again later.",
        isError: true,
      );
      return;
    }

    isSyncing.value = true;
    try {
      // Sync unsynced items
      final unsyncedItems = await dbClient.getUnsyncedItems();
      debugPrint(
        "[NotificationListController] Unsynced items count: ${unsyncedItems.length}",
      );

      for (final item in unsyncedItems) {
        try {
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
          debugPrint("[NotificationListController] Synced item: ${item.id}");
        } catch (e) {
          debugPrint("[NotificationController] Item ${item.id} failed: $e");
          _showToast("Failed to sync item: ${e.toString()}", isError: true);
          return; // Stop sync if item fails
        }
      }

      // Sync unsynced notifications
      final unsyncedNotifs = await dbClient.getUnsyncedNotifications();
      debugPrint(
        "[NotificationListController] Unsynced notifications count: ${unsyncedNotifs.length}",
      );

      for (final notif in unsyncedNotifs) {
        try {
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
          debugPrint(
            "[NotificationListController] Synced notification: ${notif.id}",
          );
        } catch (e) {
          final errorMsg = "Notification ${notif.id} failed to sync: $e";
          debugPrint("[NotificationListController] $errorMsg");
          _showToast(errorMsg, isError: true);
          return; // Stop sync if notification fails
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

      _showToast("Data synced successfully");
      await fetchNotifications();
    } finally {
      isSyncing.value = false;
      debugPrint("[NotificationListController] syncUnsyncedData complete");
    }
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
