import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/notification_list_controller.dart';

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationListController>();
    debugPrint("[NotificationListView] Building UI");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Unsynced Data',
            onPressed: controller.isSyncing.value
                ? null // Disable button while syncing
                : () async {
                    debugPrint('[NotificationListView] Sync button pressed');
                    await controller.syncUnsyncedData();
                  },
          ),
        ],
      ),
      body: Obx(() {
        debugPrint(
          "[NotificationListView] Notifications count: ${controller.notifications.length}",
        );

        if (controller.notifications.isEmpty) {
          debugPrint("[NotificationListView] No notifications found");
          return const Center(child: Text("No notifications found"));
        }

        return RefreshIndicator(
          onRefresh: () async {
            debugPrint("[NotificationListView] Pull-to-refresh triggered");
            await controller.fetchNotifications();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: controller.notifications.length,
            itemBuilder: (context, index) {
              final notif = controller.notifications[index];
              debugPrint(
                "[NotificationListView] Rendering notification index $index -> ${notif.id}",
              );

              final synced = notif.synced;
              final dateStr = DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(DateTime.parse(notif.updatedAt));

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: synced ? Colors.green : Colors.orange,
                    width: 1.5,
                  ),
                ),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    notif.type == 'incoming'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: notif.type == 'incoming'
                        ? Colors.green.shade700
                        : Colors.red,
                  ),
                  title: Text(
                    "${notif.itemId} (${notif.type == 'incoming' ? '+' : '-'}${notif.count})",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${notif.warehouseId}, ${notif.locationId}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            synced ? Icons.cloud_done : Icons.cloud_upload,
                            size: 14,
                            color: synced ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            synced ? "Synced" : "Pending Sync",
                            style: TextStyle(
                              fontSize: 11,
                              color: synced ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
