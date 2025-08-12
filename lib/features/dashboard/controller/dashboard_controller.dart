import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/core/routes/app_routes.dart';

class DashboardController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;
  final ConnectivityClient connectivityClient;
  final SharedPreferences prefs;

  DashboardController({
    required this.dbClient,
    required this.firebaseClient,
    required this.connectivityClient,
    required this.prefs,
  });

  var selectedLocationId = RxnString();
  var selectedWarehouseId = RxnString();
  var selectedItemId = RxnString();
  var selectedItem = Rxn<Map<String, dynamic>>();
  var notificationType = YStrings.transactionIncoming.obs;
  var count = 1.obs;

  var locations = <Map<String, dynamic>>[].obs;
  var warehouses = <Map<String, dynamic>>[].obs;
  var items = <Map<String, dynamic>>[].obs;

  var isSubmitting = false.obs;
  var isLoadingItems = false.obs;

  final Set<String> lastUnsyncedItemIds = {};

  bool get isOutgoing => notificationType.value == YStrings.transactionOutgoing;

  @override
  void onInit() {
    super.onInit();
    debugPrint("[DashboardController] onInit() called");
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    debugPrint("[DashboardController] Fetching locations from DB...");
    final locModels = await dbClient.getLocations();
    debugPrint("[DashboardController] Found ${locModels.length} locations");
    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((l) => {YStrings.colId: l.id, YStrings.colName: l.name})
        .toList();
    debugPrint("[DashboardController] Locations loaded: $locations");
  }

  Future<void> fetchWarehouses(String locationId) async {
    debugPrint(
      "[DashboardController] Fetching warehouses for locationId: $locationId",
    );
    final whModels = await dbClient.getWarehousesByLocationId(locationId);
    debugPrint("[DashboardController] Found ${whModels.length} warehouses");
    whModels.sort((a, b) => a.name.compareTo(b.name));
    warehouses.value = whModels
        .map((w) => {YStrings.colId: w.id, YStrings.colName: w.name})
        .toList();

    selectedWarehouseId.value = null;
    items.clear();
    selectedItemId.value = null;
    selectedItem.value = null;
  }

  Future<void> fetchItems(String warehouseId) async {
    debugPrint(
      "[DashboardController] Fetching items for warehouseId: $warehouseId",
    );
    isLoadingItems.value = true;
    items.clear();
    selectedItem.value = null;
    selectedItemId.value = null;

    final itemModels = await dbClient.getItemsByWarehouseId(warehouseId);
    debugPrint("[DashboardController] Found ${itemModels.length} items");
    itemModels.sort((a, b) => a.name.compareTo(b.name));
    items.value = itemModels
        .map(
          (i) => {
            YStrings.colId: i.id,
            YStrings.colName: i.name,
            YStrings.colQuantity: i.quantity,
          },
        )
        .toList();
    isLoadingItems.value = false;
  }

  /// This is the unified submit method: sync old unsynced -> submit current -> update metadata
  Future<void> submitNotification() async {
    final selectedId = selectedItemId.value;
    final now = DateTime.now();

    if (selectedId != null && lastUnsyncedItemIds.contains(selectedId)) {
      _showToast(
        "Last operation for this item is still pending sync. Please sync before proceeding.",
        isError: true,
      );
      return;
    }

    if (selectedId == null ||
        selectedWarehouseId.value == null ||
        selectedLocationId.value == null) {
      _showToast('Please select all fields.', isError: true);
      return;
    }

    isSubmitting.value = true;

    try {
      final hasNetwork = await connectivityClient.getSmartStatus();
      debugPrint("[DashboardController] Network available? $hasNetwork");

      if (hasNetwork) {
        // 1️⃣ Push old unsynced items
        final oldItems = await dbClient.getUnsyncedItems();
        for (final item in oldItems) {
          try {
            await firebaseClient.saveItem(item);
            await dbClient.markItemsAsSynced([item.id]);
            debugPrint("[DashboardController] Old item synced: ${item.id}");
          } catch (e) {
            _showToast(
              "Error syncing old item: ${e.toString()}",
              isError: true,
            );
            return;
          }
        }

        // 2️⃣ Push old unsynced notifications
        final oldNotifs = await dbClient.getUnsyncedNotifications();
        for (final notif in oldNotifs) {
          try {
            await firebaseClient.saveNotification(notif);
            await dbClient.markNotificationsAsSynced([notif.id]);
            debugPrint(
              "[DashboardController] Old notification synced: ${notif.id}",
            );
          } catch (e) {
            _showToast(
              "Error syncing old notification: ${e.toString()}",
              isError: true,
            );
            return;
          }
        }

        // 3️⃣ Submit the current notification
        await _submitCurrentNotification(syncToFirebase: true);

        // 4️⃣ Update metadata on both remote/server and locally
        try {
          await firebaseClient.updateSyncMetadata(YStrings.items, now);
          await firebaseClient.updateSyncMetadata(YStrings.notifications, now);
        } catch (e) {
          debugPrint("[DashboardController] Remote metadata update failed: $e");
        }
        await dbClient.updateSyncMetadata(YStrings.items, now);
        await dbClient.updateSyncMetadata(YStrings.notifications, now);
        debugPrint("[DashboardController] Metadata updated");
      } else {
        debugPrint(
          "[DashboardController] Offline mode -> Save directly locally",
        );
        await _submitCurrentNotification(syncToFirebase: false);
        await dbClient.updateSyncMetadata(YStrings.items, now);
        await dbClient.updateSyncMetadata(YStrings.notifications, now);
      }
    } finally {
      isSubmitting.value = false;
      debugPrint("[DashboardController] submitNotification complete");
    }
  }

  Future<void> _submitCurrentNotification({
    required bool syncToFirebase,
  }) async {
    final selectedId = selectedItemId.value!;
    final allItems = await dbClient.getItemsByWarehouseId(
      selectedWarehouseId.value!,
    );
    final item = allItems.firstWhere((i) => i.id == selectedId);

    int currentQty = item.quantity;
    int newQty = currentQty;

    if (isOutgoing) {
      if (count.value > currentQty) {
        throw Exception(YStrings.errNotEnoughStock);
      }
      newQty -= count.value;
    } else {
      newQty += count.value;
    }

    final now = DateTime.now();
    final updatedAt = now.toIso8601String();

    final updatedItem = item.copyWith(
      quantity: newQty,
      updatedAt: updatedAt,
      synced: syncToFirebase,
    );

    final newNotification = NotificationModel(
      id: const Uuid().v4(),
      type: notificationType.value,
      itemId: selectedId,
      count: count.value,
      warehouseId: selectedWarehouseId.value!,
      locationId: selectedLocationId.value!,
      updatedAt: updatedAt,
      synced: syncToFirebase,
    );

    if (syncToFirebase) {
      try {
        await firebaseClient.submitNotification(
          type: notificationType.value,
          itemId: selectedId,
          count: count.value,
          warehouseId: selectedWarehouseId.value!,
          locationId: selectedLocationId.value!,
        );

        await dbClient.insertItems([updatedItem]);
        await dbClient.insertNotifications([newNotification]);
        lastUnsyncedItemIds.remove(selectedId);
        _showToast("Notification submitted & synced");
      } catch (e) {
        await dbClient.insertItems([updatedItem.copyWith(synced: false)]);
        await dbClient.insertNotifications([
          newNotification.copyWith(synced: false),
        ]);
        lastUnsyncedItemIds.add(selectedId);
        _showToast(
          "Saved locally but failed to sync: ${e.toString()}",
          isError: true,
        );
      }
    } else {
      await dbClient.insertItems([updatedItem.copyWith(synced: false)]);
      await dbClient.insertNotifications([
        newNotification.copyWith(synced: false),
      ]);
      lastUnsyncedItemIds.add(selectedId);
      _showToast("Saved locally, will sync later", isError: true);
    }

    await refreshSelectedItem(selectedId);
    count.value = 1;
  }

  Future<void> refreshSelectedItem(String itemId) async {
    final allItems = await dbClient.getItemsByWarehouseId(
      selectedWarehouseId.value!,
    );
    final updatedItem = allItems.firstWhere(
      (i) => i.id == itemId,
      orElse: () => ItemModel.empty(),
    );
    selectedItem.value = {
      YStrings.colId: updatedItem.id,
      YStrings.colName: updatedItem.name,
      YStrings.colQuantity: updatedItem.quantity,
    };
  }

  void _showToast(String message, {bool isError = false}) {
    debugPrint("[DashboardController] ${isError ? 'ERROR' : 'INFO'}: $message");
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void continueToNotificationList() {
    debugPrint('[DashboardController] Navigating to NotificationList');
    Get.toNamed(AppRoutes.notificationList);
  }
}
