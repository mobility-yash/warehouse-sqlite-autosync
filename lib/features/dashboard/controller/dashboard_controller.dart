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
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    final locModels = await dbClient.getLocations();
    locModels.sort((a, b) => a.name.compareTo(b.name));
    locations.value = locModels
        .map((l) => {YStrings.colId: l.id, YStrings.colName: l.name})
        .toList();
  }

  Future<void> fetchWarehouses(String locationId) async {
    final whModels = await dbClient.getWarehousesByLocationId(locationId);
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
  }

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

      if (hasNetwork) {
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

        await _submitCurrentNotification(syncToFirebase: true);

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
      _showToast("Error: ${e.toString()}", isError: true);
    } finally {
      isSubmitting.value = false;
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
    int newQty = isOutgoing
        ? currentQty - count.value
        : currentQty + count.value;

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
        lastUnsyncedItemIds.remove(selectedId);
        _showToast("Notification submitted & synced");
      } else {
        await dbClient.insertItems([updatedItem]);
        await dbClient.insertNotifications([newNotification]);
        lastUnsyncedItemIds.add(selectedId);
        _showToast("Saved locally, will sync later", isError: true);
      }
    } catch (e) {
      await dbClient.insertItems([updatedItem.copyWith(syncedAt: null)]);
      await dbClient.insertNotifications([
        newNotification.copyWith(syncedAt: null),
      ]);
      lastUnsyncedItemIds.add(selectedId);
      _showToast(
        "Saved locally but failed to sync: ${e.toString()}",
        isError: true,
      );
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
    Get.toNamed(AppRoutes.notificationList);
  }
}
