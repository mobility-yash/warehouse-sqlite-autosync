import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

import '../controller/dashboard_controller.dart';
import 'widget/custom_dropdown_field.dart';

class DashboardView extends StatelessWidget {
  DashboardView({super.key});
  final DashboardController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'View Notifications',
            onPressed: () => controller.continueToNotificationList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Obx(() {
                final selectedLocation = controller.selectedLocationId.value;
                final selectedWarehouse = controller.selectedWarehouseId.value;
                final selectedItem = controller.selectedItem.value;
                final qty = controller.count.value;
                final isOutgoing = controller.isOutgoing;
                final currentQty = selectedItem?[YStrings.colQuantity] ?? 0;
                Widget infoTextWidget = const SizedBox();

                if (selectedLocation != null &&
                    selectedWarehouse != null &&
                    selectedItem != null) {
                  final locationName =
                      controller.locations.firstWhereOrNull(
                        (loc) => loc[YStrings.colId] == selectedLocation,
                      )?[YStrings.colName] ??
                      '';
                  final warehouseName =
                      controller.warehouses.firstWhereOrNull(
                        (wh) => wh[YStrings.colId] == selectedWarehouse,
                      )?[YStrings.colName] ??
                      '';

                  final remainingQty = isOutgoing
                      ? currentQty - qty
                      : currentQty + qty;

                  infoTextWidget = Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'You are about to '),
                        TextSpan(
                          text: isOutgoing ? 'export ' : 'import ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              '$qty ${selectedItem?[YStrings.colName] ?? 'items'} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: isOutgoing ? 'from ' : 'to '),
                        TextSpan(
                          text: '$warehouseName, $locationName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '. Current stock is '),
                        TextSpan(
                          text: '$currentQty',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: ' and after transaction it will be ',
                        ),
                        TextSpan(
                          text: '$remainingQty',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    CustomDropdownField(
                      hint: 'Select Location',
                      value: selectedLocation,
                      items: controller.locations.toList(),
                      isLoading: false,
                      onChanged: (value) {
                        controller.selectedLocationId.value = value;
                        if (value != null) {
                          controller.fetchWarehouses(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomDropdownField(
                      hint: 'Select Warehouse',
                      value: selectedWarehouse,
                      items: controller.warehouses,
                      isLoading: false,
                      onChanged: (value) {
                        controller.selectedWarehouseId.value = value;
                        if (value != null) controller.fetchItems(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomDropdownField(
                      hint: 'Select Item',
                      value: controller.selectedItemId.value,
                      items: controller.items,
                      isLoading: controller.isLoadingItems.value,
                      onChanged: (value) {
                        final item = controller.items.firstWhere(
                          (i) => i[YStrings.colId] == value,
                        );
                        controller.selectedItemId.value = value;
                        controller.selectedItem.value = item;
                        if (controller.isOutgoing &&
                            controller.count.value >
                                item[YStrings.colQuantity]) {
                          controller.count.value = item[YStrings.colQuantity];
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Incoming'),
                            value: YStrings.transactionIncoming,
                            groupValue: controller.notificationType.value,
                            onChanged: (val) =>
                                controller.notificationType.value = val!,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Outgoing'),
                            value: YStrings.transactionOutgoing,
                            groupValue: controller.notificationType.value,
                            onChanged: (val) =>
                                controller.notificationType.value = val!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: (selectedItem == null || qty <= 0)
                              ? null
                              : () => controller.count.value--,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed:
                              (selectedItem == null ||
                                  (isOutgoing && qty >= currentQty) ||
                                  (!isOutgoing && qty >= 50))
                              ? null
                              : () => controller.count.value++,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: infoTextWidget,
                    ),
                  ],
                );
              }),
            ),
          ),
          Obx(
            () => Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (controller.selectedItem.value == null ||
                          controller.isSubmitting.value)
                      ? null
                      : controller.submitNotification, // unified method
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Notification'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
