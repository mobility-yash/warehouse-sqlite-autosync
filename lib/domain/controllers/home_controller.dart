import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/services/db_helper.dart';
import 'package:warehouse_data_autosync/data/models/item.dart';
import 'package:warehouse_data_autosync/data/models/operation.dart';

import 'sync_controller.dart'; // Import SyncController to trigger sync

class HomeController extends GetxController {
  final items = <Item>[].obs;
  final selectedOperationType = OperationType.import.obs;
  final selectedQuantity = 0.obs;
  final isProcessing = false.obs;

  final SyncController syncController =
      Get.find(); // Assumes registered elsewhere

  Future<void> loadLocalItems() async {
    final db = await DBHelper.initDB();
    final data = await db.query('items');
    items.value = data
        .map(
          (e) => Item(
            id: e['id'] as String,
            name: e['name'] as String,
            quantity: e['quantity'] as int,
            lastFirebaseModified: DateTime.parse(
              e['lastFirebaseModified'] as String,
            ),
            lastLocalUpdate: DateTime.parse(e['lastLocalUpdate'] as String),
          ),
        )
        .toList();
  }

  void incrementQuantity(Item? item) {
    if (item == null) return;
    if (selectedOperationType.value == OperationType.export) {
      if (selectedQuantity.value < item.quantity) {
        selectedQuantity.value++;
      } else {
        Get.snackbar(
          "Limit reached",
          "You can export only ${item.quantity} units.",
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else if (selectedOperationType.value == OperationType.import) {
      selectedQuantity.value++;
    }
  }

  void decrementQuantity() {
    if (selectedQuantity.value > 1) selectedQuantity.value--;
  }

  Future<void> submitOperation(Item item) async {
    if (isProcessing.value) return;
    if (selectedQuantity.value <= 0) {
      Get.snackbar(
        "Invalid quantity",
        "Quantity must be greater than zero.",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    if (selectedOperationType.value == OperationType.export &&
        selectedQuantity.value > item.quantity) {
      Get.snackbar(
        "Not feasible",
        "You can export only ${item.quantity} units, adjust quantity.",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    isProcessing.value = true;

    final op = Operation(
      uuid: const Uuid().v4(),
      itemId: item.id,
      itemName: item.name,
      type: selectedOperationType.value,
      quantity: selectedQuantity.value,
      localPerformedAt: DateTime.now(),
    );

    final db = await DBHelper.initDB();

    try {
      await db.insert('operations', {
        "uuid": op.uuid,
        "itemId": op.itemId,
        "itemName": op.itemName,
        "type": op.type.name,
        "quantity": op.quantity,
        "localPerformedAt": op.localPerformedAt.toIso8601String(),
        "status": op.status.name,
      });
    } catch (e) {
      isProcessing.value = false;
      Get.snackbar(
        "DB Error",
        "Failed to store operation locally: $e",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    if (op.type == OperationType.export) {
      item.quantity -= op.quantity;
    } else {
      item.quantity += op.quantity;
    }

    try {
      await db.update(
        'items',
        {'quantity': item.quantity},
        where: 'id=?',
        whereArgs: [item.id],
      );
      items.refresh();
    } catch (e) {
      isProcessing.value = false;
      Get.snackbar(
        "DB Error",
        "Failed to update item quantity: $e",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      Get.snackbar(
        "Offline",
        "Operation saved locally, will sync later.",
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      isProcessing.value = false;
      return;
    }

    try {
      await syncController.runSync();
      Get.snackbar(
        "Success",
        "Operation synced successfully.",
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      Get.snackbar(
        "Sync Failed",
        "Operation saved locally. Sync failed: $e\n"
            "Will retry automatically later.",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      isProcessing.value = false;
    }
  }
}
