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
          (table) => controller.tableSynced[table] == true,
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
                  trailing: _buildTrailingIcon(controller, table),
                ),
              ),

            const SizedBox(height: 20),

            // Only show this when NOT loading and at least one failed
            if (!controller.isLoading.value &&
                controller.tableSynced.values.contains(false))
              ElevatedButton(
                onPressed: controller.resyncFailedTables,
                child: const Text('Resync All Failed'),
              ),

            const SizedBox(height: 20),

            if (allSynced && !controller.isLoading.value)
              ElevatedButton(
                onPressed: controller.continueToDashboard,
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

  Widget _buildTrailingIcon(SyncController c, String table) {
    if (c.tableSyncing[table] == true) {
      // Currently syncing
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (c.tableSynced[table] == true) {
      // Success
      return const Icon(Icons.check, color: Colors.green);
    } else {
      // Failed
      return const Icon(Icons.close, color: Colors.red);
    }
  }
}
