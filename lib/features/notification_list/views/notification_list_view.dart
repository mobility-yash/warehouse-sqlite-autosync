import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  Future<String> getNameById(String collection, String id) async {
    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .get();
    return doc.exists ? doc['name'] : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('notifications')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final type = doc['type'];
              final count = doc['count'];
              final itemId = doc['itemId'];
              final warehouseId = doc['warehouseId'];
              final locationId = doc['locationId'];
              final updatedAt = DateTime.parse(doc['updatedAt']);
              final dateStr = DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(updatedAt);

              return FutureBuilder(
                future: Future.wait([
                  getNameById('items', itemId),
                  getNameById('warehouses', warehouseId),
                  getNameById('locations', locationId),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }

                  final itemName = snapshot.data![0];
                  final warehouseName = snapshot.data![1];
                  final locationName = snapshot.data![2];

                  return ListTile(
                    leading: Icon(
                      type == 'incoming'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: type == 'incoming' ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '$itemName (${type == 'incoming' ? '+' : '-'}$count)',
                    ),
                    subtitle: Text(
                      '$warehouseName, $locationName\n$dateStr',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
