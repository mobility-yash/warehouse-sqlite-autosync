import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/features/sync/controller/sync_controller.dart';

class SyncView extends GetView<SyncController> {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sync Status')),
      body: Obx(() {
        final allTables = YArrays.allTables;
        final allSynced = allTables.every(
          (t) => controller.tableSynced[t] == true,
        );
        final isAnyTableSyncing =
            controller.isLoading.value ||
            controller.tableSyncing.containsValue(true);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (isAnyTableSyncing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please keep the app open while syncing to avoid interruptions.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.separated(
                    itemCount: allTables.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final table = allTables[index];
                      return _buildSyncCard(table);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                if (!isAnyTableSyncing &&
                    controller.tableSynced.values.contains(false))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Resync All Failed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: controller.resyncFailedTables,
                    ),
                  ),

                if (allSynced && !isAnyTableSyncing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Continue to Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: controller.continueToDashboard,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSyncCard(String table) {
    return Obx(() {
      final isSyncing = controller.tableSyncing[table] == true;
      final isSynced = controller.tableSynced[table] == true;
      final errorMsg = controller.tableErrors[table];

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: isSynced
                ? Colors.green.shade100
                : isSyncing
                ? Colors.blue.shade100
                : Colors.red.shade100,
            child: isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_off,
                    color: isSynced ? Colors.green : Colors.red,
                  ),
          ),
          title: Text(
            table,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSynced
                    ? 'Last synced successfully'
                    : isSyncing
                    ? 'Syncing in progress...'
                    : 'Not synced',
                style: TextStyle(
                  color: isSynced
                      ? Colors.green
                      : isSyncing
                      ? Colors.blue
                      : Colors.red,
                ),
              ),
              if (errorMsg != null && errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
          trailing: !isSyncing
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => controller.resyncTable(table),
                )
              : null,
        ),
      );
    });
  }
}
