import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/controllers/sync_controller.dart';

class SyncScreen extends StatelessWidget {
  final SyncController controller = Get.put(SyncController());

  @override
  Widget build(BuildContext context) {
    final collections = {
      SyncCollection.items: "Items Collection",
      SyncCollection.operations: "Operations Collection",
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Data Sync")),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Obx(() {
            return Column(
              children: [
                ...collections.entries.map((entry) {
                  final col = entry.key;
                  final colName = entry.value;
                  final status =
                      controller.collectionStatus[col] ?? SyncStatus.waiting;
                  final error = controller.failedErrors[col] ?? '';

                  Widget statusWidget;

                  switch (status) {
                    case SyncStatus.waiting:
                      statusWidget = const Text(
                        "Waiting to sync",
                        style: TextStyle(color: Colors.grey),
                      );
                      break;
                    case SyncStatus.syncing:
                      statusWidget = Row(
                        children: const [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Syncing...",
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      );
                      break;
                    case SyncStatus.success:
                      statusWidget = const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      );
                      break;
                    case SyncStatus.failed:
                      statusWidget = const Icon(Icons.error, color: Colors.red);
                      break;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(colName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          statusWidget,
                          if (status == SyncStatus.failed && error.isNotEmpty)
                            Text(
                              error,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: Obx(() {
                    final anyFailed = controller.collectionStatus.values.any(
                      (status) => status == SyncStatus.failed,
                    );
                    final allSuccess = controller.collectionStatus.values.every(
                      (status) => status == SyncStatus.success,
                    );

                    // Show Continue if all success
                    if (allSuccess) {
                      return ElevatedButton(
                        onPressed: () {
                          // Navigate to home screen after success
                          Get.offAllNamed('/home');
                        },
                        child: const Text("Continue"),
                      );
                    }

                    // Show Sync button if sync not running
                    if (!controller.isSyncing.value) {
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.sync),
                        onPressed: () {
                          controller.runSync();
                        },
                        label: Text(anyFailed ? "Retry Sync" : "Start Sync"),
                      );
                    }

                    // When syncing show disabled button with progress
                    return ElevatedButton.icon(
                      icon: Container(
                        height: 16,
                        width: 16,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      onPressed: null,
                      label: const Text("Syncing..."),
                    );
                  }),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
