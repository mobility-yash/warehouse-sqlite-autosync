import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/data/models/item.dart';
import 'package:warehouse_data_autosync/data/models/operation.dart';
import 'package:warehouse_data_autosync/domain/controllers/home_controller.dart';

class HomeScreen extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());
  final Rx<Item?> selectedItem = Rx<Item?>(null);

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    controller.loadLocalItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Warehouse"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Operations",
            onPressed: () => Get.toNamed('/operations'),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Sync",
            onPressed: () => Get.toNamed('/sync'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final items = controller.items;
            if (items.isEmpty) {
              return const Center(child: Text("No items found"));
            }

            final canImport = selectedItem.value != null;
            final canExport =
                selectedItem.value != null && selectedItem.value!.quantity > 0;

            final canIncrement =
                selectedItem.value != null &&
                (controller.selectedOperationType.value ==
                        OperationType.import ||
                    (controller.selectedOperationType.value ==
                            OperationType.export &&
                        controller.selectedQuantity.value <
                            selectedItem.value!.quantity));
            final canDecrement =
                selectedItem.value != null &&
                controller.selectedQuantity.value > 1;

            final canSubmit =
                selectedItem.value != null &&
                controller.selectedQuantity.value > 0 &&
                (controller.selectedOperationType.value ==
                        OperationType.import ||
                    (controller.selectedOperationType.value ==
                            OperationType.export &&
                        controller.selectedQuantity.value <=
                            selectedItem.value!.quantity));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Select Item:", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButton<Item>(
                  isExpanded: true,
                  value: selectedItem.value,
                  hint: const Text("Select an item"),
                  items: items.map((item) {
                    return DropdownMenuItem<Item>(
                      value: item,
                      child: Text("${item.name} (Qty: ${item.quantity})"),
                    );
                  }).toList(),
                  onChanged: (item) {
                    selectedItem.value = item;
                    controller.selectedQuantity.value = 1;
                    controller.selectedOperationType.value =
                        OperationType.import;
                  },
                ),
                if (selectedItem.value != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Available Quantity: ${selectedItem.value!.quantity}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle,
                          color: canDecrement ? Colors.orange : Colors.grey,
                        ),
                        onPressed: canDecrement
                            ? controller.decrementQuantity
                            : null,
                      ),
                      Obx(
                        () => Text(
                          controller.selectedQuantity.value.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: canIncrement ? Colors.orange : Colors.grey,
                        ),
                        onPressed: canIncrement
                            ? () => controller.incrementQuantity(
                                selectedItem.value,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Import"),
                        selected:
                            controller.selectedOperationType.value ==
                            OperationType.import,
                        selectedColor: canImport
                            ? Colors.green.shade300
                            : Colors.grey.shade400,
                        disabledColor: Colors.grey.shade300,
                        onSelected: canImport
                            ? (_) => controller.selectedOperationType.value =
                                  OperationType.import
                            : null,
                        labelStyle: TextStyle(
                          color:
                              controller.selectedOperationType.value ==
                                      OperationType.import &&
                                  canImport
                              ? Colors.green.shade900
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 20),
                      ChoiceChip(
                        label: const Text("Export"),
                        selected:
                            controller.selectedOperationType.value ==
                            OperationType.export,
                        selectedColor: canExport
                            ? Colors.red.shade300
                            : Colors.grey.shade400,
                        disabledColor: Colors.grey.shade300,
                        onSelected: canExport
                            ? (_) => controller.selectedOperationType.value =
                                  OperationType.export
                            : null,
                        labelStyle: TextStyle(
                          color:
                              controller.selectedOperationType.value ==
                                      OperationType.export &&
                                  canExport
                              ? Colors.red.shade900
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  icon: Icon(
                    controller.selectedOperationType.value ==
                            OperationType.import
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                  label: Text(
                    controller.selectedOperationType.value ==
                            OperationType.import
                        ? "Import"
                        : "Export",
                  ),
                  onPressed: canSubmit && !controller.isProcessing.value
                      ? () async {
                          await controller.submitOperation(selectedItem.value!);
                          selectedItem.value = null;
                          controller.selectedQuantity.value = 0;
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
