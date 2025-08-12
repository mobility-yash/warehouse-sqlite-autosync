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
        final isAnyTableSyncing =
            controller.isLoading.value ||
            controller.tableSyncing.containsValue(true);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isAnyTableSyncing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '⚠ Please do not close, minimise, or switch apps while syncing is in progress.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            for (final table in allTables)
              Card(
                child: ListTile(
                  title: Text(table),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.tableSynced[table] == true
                            ? 'Synced'
                            : 'Not Synced',
                        style: TextStyle(
                          color: controller.tableSynced[table] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      if (controller.tableSynced[table] == false &&
                          (controller.tableErrors[table]?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            controller.tableErrors[table]!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: _buildTrailingIcon(controller, table),
                ),
              ),

            const SizedBox(height: 20),

            if (!isAnyTableSyncing &&
                controller.tableSynced.values.contains(false))
              ElevatedButton(
                onPressed: controller.resyncFailedTables,
                child: const Text('Resync All Failed'),
              ),

            const SizedBox(height: 20),

            if (allSynced && !isAnyTableSyncing)
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
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (c.tableSynced[table] == true) {
      return const Icon(Icons.check, color: Colors.green);
    } else {
      return const Icon(Icons.close, color: Colors.red);
    }
  }
}
