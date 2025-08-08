import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/features/sync/controller/sync_controller.dart';

class SyncView extends GetView<SyncController> {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sync')),
      body: Obx(() {
        final allTables = YArrays.allTables;

        final allSynced = allTables.every(
          (table) => controller.tableSynced[table] ?? false,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final table in allTables)
              Card(
                child: ListTile(
                  title: Text(table),
                  subtitle: Text(
                    controller.tableSynced[table] == true
                        ? 'Synced'
                        : 'Not Synced',
                    style: TextStyle(
                      color: controller.tableSynced[table] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  trailing: controller.tableSyncing[table] == true
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (controller.tableSynced[table] == false)
                      ? ElevatedButton(
                          onPressed: () => controller.resyncTable(table),
                          child: const Text('Resync'),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: controller.resyncFailedTables,
              child: const Text('Resync All Failed'),
            ),

            const SizedBox(height: 20),

            if (allSynced)
              ElevatedButton(
                onPressed: () {
                  // Manually move forward, no auto redirect
                  Get.offNamed('/next-screen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
          ],
        );
      }),
    );
  }
}
