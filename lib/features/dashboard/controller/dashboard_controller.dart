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
    debugPrint("[fetchLocations] Fetching locations from DB...");
    final locModels = await dbClient.getLocations();
    debugPrint("[fetchLocations] Found ${locModels.length} locations");
    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((l) => {YStrings.colId: l.id, YStrings.colName: l.name})
        .toList();
    debugPrint("[fetchLocations] Locations loaded: $locations");
  }

  Future<void> fetchWarehouses(String locationId) async {
    debugPrint("[fetchWarehouses] Fetching for locationId: $locationId");
    final whModels = await dbClient.getWarehousesByLocationId(locationId);
    debugPrint("[fetchWarehouses] Found ${whModels.length} warehouses");
    whModels.sort((a, b) => a.name.compareTo(b.name));
    warehouses.value = whModels
        .map((w) => {YStrings.colId: w.id, YStrings.colName: w.name})
        .toList();

    // Reset state
    selectedWarehouseId.value = null;
    items.clear();
    selectedItemId.value = null;
    selectedItem.value = null;
    debugPrint("[fetchWarehouses] Warehouses loaded: $warehouses");
  }

  Future<void> fetchItems(String warehouseId) async {
    debugPrint("[fetchItems] Fetching items for warehouseId: $warehouseId");
    isLoadingItems.value = true;
    items.clear();
    selectedItem.value = null;
    selectedItemId.value = null;

    final itemModels = await dbClient.getItemsByWarehouseId(warehouseId);
    debugPrint("[fetchItems] Found ${itemModels.length} items");
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
    debugPrint("[fetchItems] Items loaded: $items");
    isLoadingItems.value = false;
  }

  Future<void> submitNotification() async {
    final selectedId = selectedItemId.value;
    debugPrint("[submitNotification] Triggered for itemId: $selectedId");

    if (selectedId != null && lastUnsyncedItemIds.contains(selectedId)) {
      debugPrint("[submitNotification] BLOCKED: Previous unsynced op exists");
      _showToast(
        "Last operation for this item is still pending sync. Please sync before proceeding.",
        isError: true,
      );
      return;
    }

    if (selectedId == null ||
        selectedWarehouseId.value == null ||
        selectedLocationId.value == null) {
      debugPrint("[submitNotification] BLOCKED: Missing fields");
      _showToast('Please select all fields.', isError: true);
      return;
    }

    isSubmitting.value = true;

    try {
      debugPrint("[submitNotification] Fetching current item from DB");
      final allItems = await dbClient.getItemsByWarehouseId(
        selectedWarehouseId.value!,
      );
      final item = allItems.firstWhere((i) => i.id == selectedId);

      debugPrint(
        "[submitNotification] Current item: ${item.name}, qty=${item.quantity}",
      );

      int currentQty = item.quantity;
      int newQty = currentQty;

      if (isOutgoing) {
        if (count.value > currentQty) {
          debugPrint("[submitNotification] ERROR: Not enough stock");
          throw Exception(YStrings.errNotEnoughStock);
        }
        newQty -= count.value;
      } else {
        newQty += count.value;
      }
      debugPrint("[submitNotification] New quantity after op: $newQty");

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
        itemId: selectedId,
        count: count.value,
        warehouseId: selectedWarehouseId.value!,
        locationId: selectedLocationId.value!,
        updatedAt: updatedAt,
        synced: false,
      );

      debugPrint("[submitNotification] Checking network...");
      final hasNetwork = await connectivityClient.getSmartStatus();
      debugPrint("[submitNotification] Network available? $hasNetwork");

      if (hasNetwork) {
        try {
          debugPrint("[submitNotification] Sending to Firebase...");
          await firebaseClient.submitNotification(
            type: notificationType.value,
            itemId: selectedId,
            count: count.value,
            warehouseId: selectedWarehouseId.value!,
            locationId: selectedLocationId.value!,
          );

          debugPrint(
            "[submitNotification] Firebase sync success → Saving locally as synced",
          );
          await dbClient.insertItems([updatedItem.copyWith(synced: true)]);
          await dbClient.insertNotifications([
            newNotification.copyWith(synced: true),
          ]);

          lastUnsyncedItemIds.remove(selectedId);

          _showToast(
            "Notification submitted & synced with server for item '${item.name}'",
          );
        } catch (firebaseError) {
          debugPrint(
            "[submitNotification] Firebase sync FAILED: $firebaseError",
          );
          debugPrint("[submitNotification] Saving locally as unsynced");
          await dbClient.insertItems([updatedItem]);
          await dbClient.insertNotifications([newNotification]);
          lastUnsyncedItemIds.add(selectedId);

          _showToast(
            "Saved locally but failed to sync: ${firebaseError.toString()}",
            isError: true,
          );
        }
      } else {
        debugPrint("[submitNotification] Offline → Saving locally as unsynced");
        await dbClient.insertItems([updatedItem]);
        await dbClient.insertNotifications([newNotification]);
        lastUnsyncedItemIds.add(selectedId);

        _showToast(
          "No internet. Saved locally. Will sync later.",
          isError: true,
        );
      }

      debugPrint("[submitNotification] Updating sync_metadata timestamps");
      await Future.wait([
        dbClient.updateSyncMetadata(YStrings.items, now),
        dbClient.updateSyncMetadata(YStrings.notifications, now),
      ]);

      await refreshSelectedItem(selectedId);
      count.value = 1;
      debugPrint("[submitNotification] Completed for itemId: $selectedId");
    } catch (e) {
      debugPrint("[submitNotification] ERROR: $e");
      _showToast("Error: ${e.toString()}", isError: true);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> refreshSelectedItem(String itemId) async {
    debugPrint("[refreshSelectedItem] Refreshing from DB: $itemId");
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
    debugPrint("[refreshSelectedItem] Got: $selectedItem");
  }

  void _showToast(String message, {bool isError = false}) {
    debugPrint("[Toast] ${isError ? 'ERROR' : 'INFO'}: $message");
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
