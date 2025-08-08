import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/features/sync/controller/sync_controller.dart';

class SyncView extends GetView<SyncController> {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sync')),
      body: Obx(() {
        final allSynced = controller.tableSynced.values.every((e) => e);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Show each table with sync status and possible loader
            for (final table in controller.tableSynced.keys)
              Card(
                child: ListTile(
                  title: Text(table),
                  subtitle: Text(
                    controller.tableSynced[table]! ? 'Synced' : 'Not Synced',
                    style: TextStyle(
                      color: controller.tableSynced[table]!
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  trailing: controller.tableSyncing[table]!
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (!controller.tableSynced[table]!)
                      ? ElevatedButton(
                          onPressed: () => controller.resyncTable(table),
                          child: const Text('Resync'),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
              ),

            const SizedBox(height: 20),

            // Button to resync all failed tables
            ElevatedButton(
              onPressed: controller.resyncFailedTables,
              child: const Text('Resync All Failed'),
            ),

            const SizedBox(height: 20),

            // Continue button appears only when all are synced
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
