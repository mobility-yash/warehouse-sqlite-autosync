import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

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

  // Reactive state variables for selections
  var selectedLocationId = RxnString();
  var selectedWarehouseId = RxnString();
  var selectedItemId = RxnString();
  var selectedItem = Rxn<Map<String, dynamic>>();
  var notificationType = YStrings.transactionIncoming.obs;
  var count = 1.obs;

  // Lists for dropdowns
  var locations = <Map<String, dynamic>>[].obs;
  var warehouses = <Map<String, dynamic>>[].obs;
  var items = <Map<String, dynamic>>[].obs;

  // Loading indicators
  var isSubmitting = false.obs;
  var isLoadingItems = false.obs;

  bool get isOutgoing => notificationType.value == YStrings.transactionOutgoing;

  @override
  void onInit() {
    super.onInit();
    debugPrint("[DashboardController] onInit() called");
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    debugPrint("[fetchLocations] Fetching locations from DB...");
    final locModels = await dbClient.getLocations();
    debugPrint("[fetchLocations] Found ${locModels.length} locations");

    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((loc) => {YStrings.colId: loc.id, YStrings.colName: loc.name})
        .toList();

    debugPrint("[fetchLocations] Locations loaded: $locations");
  }

  Future<void> fetchWarehouses(String locationId) async {
    debugPrint("[fetchWarehouses] Location ID: $locationId");
    final warehouseModels = await dbClient.getWarehousesByLocationId(
      locationId,
    );
    debugPrint("[fetchWarehouses] Found ${warehouseModels.length} warehouses");

    warehouseModels.sort((a, b) => a.name.compareTo(b.name));
    warehouses.value = warehouseModels
        .map((w) => {YStrings.colId: w.id, YStrings.colName: w.name})
        .toList();

    // Reset selections when location changes
    selectedWarehouseId.value = null;
    items.clear();
    selectedItemId.value = null;
    selectedItem.value = null;

    debugPrint("[fetchWarehouses] Warehouses loaded: $warehouses");
  }

  Future<void> fetchItems(String warehouseId) async {
    debugPrint("[fetchItems] Warehouse ID: $warehouseId");
    isLoadingItems.value = true;

    items.clear();
    selectedItem.value = null;
    selectedItemId.value = null;

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

    debugPrint("[fetchItems] Items loaded: $items");
    isLoadingItems.value = false;
  }

  Future<void> submitNotification() async {
    debugPrint("[submitNotification] Starting submission...");

    if (selectedItemId.value == null ||
        selectedWarehouseId.value == null ||
        selectedLocationId.value == null) {
      debugPrint("[submitNotification] Missing fields!");
      Get.snackbar('Error', 'Please select all fields.');
      return;
    }

    isSubmitting.value = true;

    try {
      debugPrint("[submitNotification] Fetching current item data...");
      final allItems = await dbClient.getItemsByWarehouseId(
        selectedWarehouseId.value!,
      );
      final item = allItems.firstWhere((i) => i.id == selectedItemId.value);

      debugPrint(
        "[submitNotification] Current item: ${item.name}, qty: ${item.quantity}",
      );

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

      debugPrint("[submitNotification] New quantity: $newQty");

      final now = DateTime.now();
      final updatedAt = now.toIso8601String();

      final updatedItem = item.copyWith(
        quantity: newQty,
        updatedAt: updatedAt,
        synced: false,
      );

      final newNotification = NotificationModel(
        id: const Uuid().v4(),
        type: notificationType.value,
        itemId: selectedItemId.value!,
        count: count.value,
        warehouseId: selectedWarehouseId.value!,
        locationId: selectedLocationId.value!,
        updatedAt: updatedAt,
        synced: false,
      );

      final hasNetwork = await connectivityClient.getSmartStatus();

      if (hasNetwork) {
        try {
          // Sync with Firebase
          await firebaseClient.submitNotification(
            type: notificationType.value,
            itemId: selectedItemId.value!,
            count: count.value,
            warehouseId: selectedWarehouseId.value!,
            locationId: selectedLocationId.value!,
          );

          try {
            // Save locally as synced
            await dbClient.insertItems([updatedItem.copyWith(synced: true)]);
            await dbClient.insertNotifications([
              newNotification.copyWith(synced: true),
            ]);
          } catch (localSaveError) {
            debugPrint(
              "[submitNotification] Local save after Firebase success failed: $localSaveError",
            );
            // On failure here, mark sync flags false because data not saved properly
            await _resetSyncFlags();
            rethrow; // Rethrow if you want outer catch to handle snack etc.
          }

          debugPrint(
            "[submitNotification] Data synced with Firebase and saved locally.",
          );
        } catch (firebaseError) {
          debugPrint(
            "[submitNotification] Firebase sync failed: $firebaseError",
          );

          try {
            // Save locally as unsynced on firebase failure
            await dbClient.insertItems([updatedItem]);
            await dbClient.insertNotifications([newNotification]);
          } catch (localSaveError) {
            debugPrint(
              "[submitNotification] Local save after Firebase failure also failed: $localSaveError",
            );
          }

          // Reset sync flags in prefs and state because sync failed
          await _resetSyncFlags();

          Get.snackbar(
            'Warning',
            'Saved locally but failed to sync with server.',
          );
        }
      } else {
        try {
          // No network - save locally as unsynced
          await dbClient.insertItems([updatedItem]);
          await dbClient.insertNotifications([newNotification]);
        } catch (localSaveError) {
          debugPrint(
            "[submitNotification] Local save failed with no network: $localSaveError",
          );
        }

        // Reset sync flags because no network, definitely not synced
        await _resetSyncFlags();

        debugPrint(
          "[submitNotification] No network - saved locally with synced=false.",
        );
      }

      // Update local sync_metadata for both tables regardless of network status or sync success
      await Future.wait([
        dbClient.updateSyncMetadata(YStrings.items, now),
        dbClient.updateSyncMetadata(YStrings.notifications, now),
      ]);
      debugPrint(
        "[submitNotification] Updated sync_metadata timestamps for items and notifications.",
      );

      await refreshSelectedItem(selectedItemId.value!);
      count.value = 1;
      Get.snackbar('Success', 'Notification submitted.');
    } catch (e) {
      debugPrint("[submitNotification] Error: $e");
      Get.snackbar('Error', e.toString());
    } finally {
      isSubmitting.value = false;
      debugPrint("[submitNotification] Submission complete");
    }
  }

  // Helper method to reset sync status prefs and tableSynced flags
  Future<void> _resetSyncFlags() async {
    await prefs.setBool('${YStrings.syncStatusPrefix}${YStrings.items}', false);
    await prefs.setBool(
      '${YStrings.syncStatusPrefix}${YStrings.notifications}',
      false,
    );
    await prefs.setBool(YStrings.lastInitSyncSuccess, false);
  }

  Future<void> refreshSelectedItem(String itemId) async {
    debugPrint("[refreshSelectedItem] Refreshing item: $itemId");
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

    debugPrint("[refreshSelectedItem] Updated item: $selectedItem");
  }
}
