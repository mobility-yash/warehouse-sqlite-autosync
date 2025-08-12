import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class NotificationListController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;

  NotificationListController({
    required this.dbClient,
    required this.firebaseClient,
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

  var notifications = <NotificationModel>[].obs;

  var isSubmitting = false.obs;
  var isLoadingItems = false.obs;
  var isSyncing = false.obs;

  bool get isOutgoing => notificationType.value == YStrings.transactionOutgoing;

  @override
  void onInit() {
    debugPrint("[NotificationListController] onInit() called");
    super.onInit();
    fetchLocations();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    debugPrint("[fetchNotifications] Fetching notifications from local DB...");
    final notifModels = await dbClient.getNotifications();
    debugPrint(
      "[fetchNotifications] Found ${notifModels.length} notifications in DB",
    );

    notifModels.sort((a, b) {
      if (a.synced != b.synced) {
        return a.synced ? 1 : -1;
      }
      return DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt));
    });
    notifications.value = notifModels;
    debugPrint(
      "[fetchNotifications] Updated list with ${notifications.length} notifications",
    );
  }

  Future<void> fetchLocations() async {
    debugPrint("[fetchLocations] Fetching locations from DB...");
    final locModels = await dbClient.getLocations();
    debugPrint("[fetchLocations] Found ${locModels.length} locations");

    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((loc) => {YStrings.colId: loc.id, YStrings.colName: loc.name})
        .toList();

    debugPrint("[fetchLocations] Locations loaded");
  }

  Future<void> fetchWarehouses(String locationId) async {
    debugPrint(
      "[fetchWarehouses] Fetching warehouses for locationId: $locationId",
    );
    final warehouseModels = await dbClient.getWarehousesByLocationId(
      locationId,
    );
    debugPrint("[fetchWarehouses] Found ${warehouseModels.length} warehouses");

    warehouseModels.sort((a, b) => a.name.compareTo(b.name));
    warehouses.value = warehouseModels
        .map((w) => {YStrings.colId: w.id, YStrings.colName: w.name})
        .toList();

    selectedWarehouseId.value = null;
    items.clear();
    selectedItemId.value = null;
    selectedItem.value = null;
    debugPrint("[fetchWarehouses] Warehouses list updated");
  }

  Future<void> fetchItems(String warehouseId) async {
    debugPrint("[fetchItems] Fetching items for warehouseId: $warehouseId");
    isLoadingItems.value = true;
    final itemModels = await dbClient.getItemsByWarehouseId(warehouseId);
    debugPrint("[fetchItems] Found ${itemModels.length} items");

    itemModels.sort((a, b) => a.name.compareTo(b.name));
    items.value = itemModels
        .map(
          (item) => {
            YStrings.colId: item.id,
            YStrings.colName: item.name,
            YStrings.colQuantity: item.quantity,
          },
        )
        .toList();

    isLoadingItems.value = false;
    debugPrint("[fetchItems] Items loaded");
  }

  Future<void> submitNotification() async {
    debugPrint("[submitNotification] Starting submission...");

    if (selectedItemId.value == null ||
        selectedWarehouseId.value == null ||
        selectedLocationId.value == null) {
      debugPrint("[submitNotification] Missing required fields");
      Get.snackbar('Error', 'Please select all fields.');
      return;
    }

    isSubmitting.value = true;
    try {
      final allItems = await dbClient.getItemsByWarehouseId(
        selectedWarehouseId.value!,
      );
      final item = allItems.firstWhere((i) => i.id == selectedItemId.value);

      debugPrint("[submitNotification] Current qty: ${item.quantity}");
      int newQty = item.quantity;

      if (isOutgoing) {
        if (count.value > item.quantity) {
          debugPrint("[submitNotification] Not enough stock!");
          throw Exception(YStrings.errNotEnoughStock);
        }
        newQty -= count.value;
      } else {
        newQty += count.value;
      }
      debugPrint("[submitNotification] New qty after transaction: $newQty");

      await dbClient.insertItems([
        item.copyWith(
          quantity: newQty,
          updatedAt: DateTime.now().toIso8601String(),
          synced: false,
        ),
      ]);
      debugPrint("[submitNotification] Item updated locally (synced=false)");

      await dbClient.insertNotifications([
        NotificationModel(
          id: const Uuid().v4(),
          type: notificationType.value,
          itemId: selectedItemId.value!,
          count: count.value,
          warehouseId: selectedWarehouseId.value!,
          locationId: selectedLocationId.value!,
          updatedAt: DateTime.now().toIso8601String(),
          synced: false,
        ),
      ]);
      debugPrint(
        "[submitNotification] Notification inserted locally (synced=false)",
      );

      await refreshSelectedItem(selectedItemId.value!);
      count.value = 1;

      Get.snackbar('Success', 'Notification saved locally.');
      await fetchNotifications();
    } catch (e) {
      debugPrint("[submitNotification] Error: $e");
      Get.snackbar('Error', e.toString());
    } finally {
      isSubmitting.value = false;
      debugPrint("[submitNotification] Submission complete");
    }
  }

  Future<void> refreshSelectedItem(String itemId) async {
    debugPrint("[refreshSelectedItem] Refreshing itemId: $itemId");
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
    debugPrint("[refreshSelectedItem] Updated item in selection");
  }

  /// Push all unsynced items and notifications to Firestore and mark locally as synced.
  Future<void> syncUnsyncedData() async {
    debugPrint("[syncUnsyncedData] Started");
    isSyncing.value = true;
    try {
      // Sync unsynced items
      final unsyncedItems = await dbClient.getUnsyncedItems();
      debugPrint("[syncUnsyncedData] Unsynced items: ${unsyncedItems.length}");
      for (final item in unsyncedItems) {
        try {
          debugPrint(
            "[syncUnsyncedData] Syncing item id: ${item.id} to Firebase...",
          );
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
          debugPrint("[syncUnsyncedData] Synced item id: ${item.id}");
        } catch (e) {
          debugPrint("[syncUnsyncedData] Item ${item.id} failed to sync: $e");
        }
      }

      // Sync unsynced notifications
      final unsyncedNotifs = await dbClient.getUnsyncedNotifications();
      debugPrint(
        "[syncUnsyncedData] Unsynced notifications: ${unsyncedNotifs.length}",
      );
      for (final notif in unsyncedNotifs) {
        try {
          debugPrint(
            "[syncUnsyncedData] Syncing notification id: ${notif.id} to Firebase...",
          );
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
          debugPrint("[syncUnsyncedData] Synced notification id: ${notif.id}");
        } catch (e) {
          debugPrint(
            "[syncUnsyncedData] Notification ${notif.id} failed to sync: $e",
          );
        }
      }

      final now = DateTime.now();
      // Update metadata on both Firestore and locally
      try {
        await firebaseClient.updateSyncMetadata(YStrings.items, now);
        await firebaseClient.updateSyncMetadata(YStrings.notifications, now);
      } catch (e) {
        debugPrint("[syncUnsyncedData] Could not update remote sync meta $e");
        // Optionally continue
      }
      await dbClient.updateSyncMetadata(YStrings.items, now);
      await dbClient.updateSyncMetadata(YStrings.notifications, now);

      debugPrint("[syncUnsyncedData] Sync metadata updated for both tables");
      await fetchNotifications();
    } finally {
      isSyncing.value = false;
      debugPrint("[syncUnsyncedData] Complete");
    }
  }
}
