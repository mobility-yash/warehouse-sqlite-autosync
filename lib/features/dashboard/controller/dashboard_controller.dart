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

  bool get isOutgoing => notificationType.value == YStrings.transactionOutgoing;

  @override
  void onInit() {
    debugPrint("Yash [DashboardController] [onInit] - Controller initialized");
    super.onInit();
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    debugPrint(
      "Yash [DashboardController] [fetchLocations] - Fetching locations",
    );
    final locModels = await dbClient.getLocations();
    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((l) => {YStrings.colId: l.id, YStrings.colName: l.name})
        .toList();
    debugPrint(
      "Yash [DashboardController] [fetchLocations] - Found ${locations.length} locations",
    );
  }

  Future<void> fetchWarehouses(String locationId) async {
    debugPrint(
      "Yash [DashboardController] [fetchWarehouses] - Location ID: $locationId",
    );
    final whModels = await dbClient.getWarehousesByLocationId(locationId);
    whModels.sort((a, b) => a.name.compareTo(b.name));
    warehouses.value = whModels
        .map((w) => {YStrings.colId: w.id, YStrings.colName: w.name})
        .toList();

    selectedWarehouseId.value = null;
    items.clear();
    selectedItemId.value = null;
    selectedItem.value = null;
    debugPrint(
      "Yash [DashboardController] [fetchWarehouses] - Found ${warehouses.length} warehouses",
    );
  }

  Future<void> fetchItems(String warehouseId) async {
    debugPrint(
      "Yash [DashboardController] [fetchItems] - Warehouse ID: $warehouseId",
    );
    isLoadingItems.value = true;
    items.clear();
    selectedItem.value = null;
    selectedItemId.value = null;

    final itemModels = await dbClient.getItemsByWarehouseId(warehouseId);
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
    debugPrint(
      "Yash [DashboardController] [fetchItems] - Found ${items.length} items",
    );
  }

  Future<void> submitNotification() async {
    final selectedId = selectedItemId.value;
    final now = DateTime.now();
    debugPrint(
      "Yash [DashboardController] [submitNotification] - Starting submission, selectedId: $selectedId",
    );

    // 1️⃣ Block if selected item already has syncedAt=null
    if (selectedId != null) {
      final items = await dbClient.getItemsByWarehouseId(
        selectedWarehouseId.value!,
      );
      final selectedItem = items.firstWhere(
        (i) => i.id == selectedId,
        orElse: () => ItemModel.empty(),
      );

      if (selectedItem.syncedAt == null) {
        debugPrint(
          "Yash [DashboardController] [submitNotification] - Item $selectedId pending sync (syncedAt=null) → blocking",
        );
        _showToast(
          "Last operation for this item is still pending sync. Please sync before proceeding.",
          isError: true,
        );
        return;
      }
    }

    // 2️⃣ Validate required selections
    if (selectedId == null ||
        selectedWarehouseId.value == null ||
        selectedLocationId.value == null) {
      debugPrint(
        "Yash [DashboardController] [submitNotification] - Missing selections",
      );
      _showToast('Please select all fields.', isError: true);
      return;
    }

    isSubmitting.value = true;
    try {
      final hasNetwork = await connectivityClient.getSmartStatus();
      debugPrint(
        "Yash [DashboardController] [submitNotification] - Has network: $hasNetwork",
      );

      if (hasNetwork) {
        // 3️⃣ Push all previously unsynced DB rows to Firebase
        debugPrint(
          "Yash [DashboardController] [submitNotification] - Syncing old unsynced records",
        );

        final oldItems = await dbClient.getUnsyncedItems();
        for (final item in oldItems) {
          await firebaseClient.saveItem(item);
          await dbClient.markItemsAsSynced([item.id]);
        }

        final oldNotifs = await dbClient.getUnsyncedNotifications();
        for (final notif in oldNotifs) {
          await firebaseClient.saveNotification(notif);
          await dbClient.markNotificationsAsSynced([notif.id]);
        }

        // 4️⃣ Submit the new notification online
        await _submitCurrentNotification(syncToFirebase: true);

        // 5️⃣ Update sync metadata
        await firebaseClient.updateSyncMetadata(
          entity: YStrings.items,
          lastTableUpdatedAt: now,
        );
        await firebaseClient.updateSyncMetadata(
          entity: YStrings.notifications,
          lastTableUpdatedAt: now,
        );

        await dbClient.updateBothLocalAndRemoteTimestamps(
          entity: YStrings.items,
          updatedAt: now.toIso8601String(),
        );
        await dbClient.updateBothLocalAndRemoteTimestamps(
          entity: YStrings.notifications,
          updatedAt: now.toIso8601String(),
        );
      } else {
        // 6️⃣ Offline save — syncedAt=null
        debugPrint(
          "Yash [DashboardController] [submitNotification] - No network — saving offline",
        );
        await _submitCurrentNotification(syncToFirebase: false);

        await dbClient.updateLastLocalUpdatedAt(
          entity: YStrings.items,
          lastLocalUpdatedAt: now.toIso8601String(),
        );
        await dbClient.updateLastLocalUpdatedAt(
          entity: YStrings.notifications,
          lastLocalUpdatedAt: now.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint("Yash [DashboardController] [submitNotification] - ERROR: $e");
      _showToast("Error: ${e.toString()}", isError: true);
    } finally {
      isSubmitting.value = false;
      debugPrint("Yash [DashboardController] [submitNotification] - Complete");
    }
  }

  Future<void> _submitCurrentNotification({
    required bool syncToFirebase,
  }) async {
    debugPrint(
      "Yash [DashboardController] [_submitCurrentNotification] - syncToFirebase: $syncToFirebase",
    );

    final selectedId = selectedItemId.value!;
    final allItems = await dbClient.getItemsByWarehouseId(
      selectedWarehouseId.value!,
    );
    final item = allItems.firstWhere((i) => i.id == selectedId);
    int currentQty = item.quantity;
    int newQty = isOutgoing
        ? currentQty - count.value
        : currentQty + count.value;

    debugPrint(
      "Yash [DashboardController] [_submitCurrentNotification] - currentQty: $currentQty, newQty: $newQty",
    );

    if (isOutgoing && newQty < 0) {
      throw Exception(YStrings.errNotEnoughStock);
    }

    final now = DateTime.now();
    final updatedItem = item.copyWith(
      quantity: newQty,
      updatedAt: now.toIso8601String(),
      syncedAt: syncToFirebase ? now.toIso8601String() : null,
    );

    final newNotification = NotificationModel(
      id: const Uuid().v4(),
      type: notificationType.value,
      itemId: selectedId,
      count: count.value,
      warehouseId: selectedWarehouseId.value!,
      locationId: selectedLocationId.value!,
      updatedAt: now.toIso8601String(),
      syncedAt: syncToFirebase ? now.toIso8601String() : null,
    );

    try {
      if (syncToFirebase) {
        await firebaseClient.submitNotification(
          type: notificationType.value,
          itemId: selectedId,
          count: count.value,
          warehouseId: selectedWarehouseId.value!,
          locationId: selectedLocationId.value!,
        );
        await dbClient.insertItems([updatedItem]);
        await dbClient.insertNotifications([newNotification]);
        _showToast("Notification submitted & synced");
      } else {
        // Offline → force syncedAt=null
        await dbClient.insertItems([updatedItem.copyWith(syncedAt: null)]);
        await dbClient.insertNotifications([
          newNotification.copyWith(syncedAt: null),
        ]);
        _showToast(
          "No internet. Saved locally, will sync later.",
          isError: true,
        );
      }
    } catch (e) {
      await dbClient.insertItems([updatedItem.copyWith(syncedAt: null)]);
      await dbClient.insertNotifications([
        newNotification.copyWith(syncedAt: null),
      ]);
      _showToast(
        "Saved locally but failed to sync: ${e.toString()}",
        isError: true,
      );
    }

    await refreshSelectedItem(selectedId);
    count.value = 1;
  }

  Future<void> refreshSelectedItem(String itemId) async {
    debugPrint(
      "Yash [DashboardController] [refreshSelectedItem] - itemId: $itemId",
    );
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
    debugPrint(
      "Yash [DashboardController] [refreshSelectedItem] - Updated item: ${updatedItem.id}",
    );
  }

  void _showToast(String message, {bool isError = false}) {
    debugPrint(
      "Yash [DashboardController] [_showToast] - ${isError ? 'ERROR' : 'INFO'}: $message",
    );
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
    debugPrint(
      "Yash [DashboardController] [continueToNotificationList] - Navigating to notification list",
    );
    Get.toNamed(AppRoutes.notificationList);
  }
}
