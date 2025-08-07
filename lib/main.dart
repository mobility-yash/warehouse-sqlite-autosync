import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedLocationId;
  String? selectedWarehouseId;
  String? selectedItemId;
  DocumentSnapshot? selectedItem;
  String notificationType = 'incoming';
  int count = 1;

  List<DocumentSnapshot> locations = [];
  List<DocumentSnapshot> warehouses = [];
  List<DocumentSnapshot> items = [];

  bool get isOutgoing => notificationType == 'outgoing';
  bool isSubmitting = false;
  bool isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    final snapshot = await _firestore.collection('locations').get();
    final sorted = snapshot.docs
      ..sort((a, b) => a['name'].compareTo(b['name']));
    setState(() {
      locations = sorted;
    });
  }

  Future<void> fetchWarehouses(String locationId) async {
    final snapshot = await _firestore
        .collection('warehouses')
        .where('locationId', isEqualTo: locationId)
        .get();
    final sorted = snapshot.docs
      ..sort((a, b) => a['name'].compareTo(b['name']));
    setState(() {
      warehouses = sorted;
      selectedWarehouseId = null;
      items = [];
      selectedItemId = null;
      selectedItem = null;
    });
  }

  Future<void> fetchItems(String warehouseId) async {
    setState(() {
      isLoadingItems = true;
      items = [];
      selectedItem = null;
      selectedItemId = null;
    });

    final snapshot = await _firestore
        .collection('items')
        .where('warehouseId', isEqualTo: warehouseId)
        .get();

    final sorted = snapshot.docs
      ..sort((a, b) => a['name'].compareTo(b['name']));

    setState(() {
      items = sorted;
      isLoadingItems = false;
    });
  }

  Future<void> submitNotification() async {
    if (selectedItemId == null ||
        selectedWarehouseId == null ||
        selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all fields.')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await _firestore.runTransaction((transaction) async {
        final itemRef = _firestore.collection('items').doc(selectedItemId);
        final snapshot = await transaction.get(itemRef);

        if (!snapshot.exists) throw Exception('Item not found.');

        final data = snapshot.data()!;
        int currentQty = data['quantity'] ?? 0;
        int newQty = currentQty;

        if (notificationType == 'outgoing') {
          if (count > currentQty) {
            throw Exception('Not enough stock for outgoing!');
          }
          newQty -= count;
        } else {
          newQty += count;
        }

        transaction.update(itemRef, {
          'quantity': newQty,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'id': const Uuid().v4(),
          'type': notificationType,
          'itemId': selectedItemId,
          'count': count,
          'warehouseId': selectedWarehouseId,
          'locationId': selectedLocationId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });

      await refreshSelectedItem(selectedItemId!);

      setState(() {
        count = 1;
        isSubmitting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification submitted.')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> refreshSelectedItem(String itemId) async {
    final updatedSnapshot = await _firestore
        .collection('items')
        .doc(itemId)
        .get();
    if (updatedSnapshot.exists) {
      setState(() {
        selectedItem = updatedSnapshot;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItemQty = selectedItem != null
        ? selectedItem!['quantity'] ?? 0
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'View Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // LOCATION DROPDOWN
            DropdownButtonFormField<String>(
              value: selectedLocationId,
              hint: const Text('Select Location'),
              items: locations.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(doc['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLocationId = value;
                });
                fetchWarehouses(value!);
              },
            ),
            const SizedBox(height: 16),

            // WAREHOUSE DROPDOWN
            DropdownButtonFormField<String>(
              value: selectedWarehouseId,
              hint: const Text('Select Warehouse'),
              items: warehouses.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(doc['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedWarehouseId = value;
                });
                fetchItems(value!);
              },
            ),
            const SizedBox(height: 16),

            // ITEM DROPDOWN
            DropdownButtonFormField<String>(
              value: selectedItemId,
              hint: const Text('Select Item'),
              items: items.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(doc['name']),
                );
              }).toList(),
              onTap: () {
                if (selectedWarehouseId != null) {
                  fetchItems(selectedWarehouseId!);
                }
              },
              onChanged: (value) {
                final item = items.firstWhere((item) => item.id == value);
                setState(() {
                  selectedItemId = value;
                  selectedItem = item;

                  if (isOutgoing && count > item['quantity']) {
                    count = item['quantity'];
                  }
                });
              },
            ),

            if (selectedItem != null && !isLoadingItems)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Current Quantity: ${selectedItem!['quantity']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else if (isLoadingItems)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

            const SizedBox(height: 16),

            // RADIO BUTTONS
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Incoming'),
                    value: 'incoming',
                    groupValue: notificationType,
                    onChanged: (val) {
                      setState(() {
                        notificationType = val!;
                        if (selectedItem != null &&
                            count > selectedItem!['quantity']) {
                          count = selectedItem!['quantity'];
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Outgoing'),
                    value: 'outgoing',
                    groupValue: notificationType,
                    onChanged: (val) {
                      setState(() {
                        notificationType = val!;
                        if (selectedItem != null &&
                            count > selectedItem!['quantity']) {
                          count = selectedItem!['quantity'];
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QUANTITY COUNTER
            Row(
              children: [
                Text('Quantity: '),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.first_page), // Set to 0
                    tooltip: 'Set to 0',
                    onPressed: selectedItem == null
                        ? null
                        : () => setState(() => count = 0),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: (selectedItem == null || count <= 0)
                        ? null
                        : () => setState(() => count--),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed:
                        (selectedItem == null ||
                            (isOutgoing &&
                                count >= (selectedItem!['quantity'] ?? 0)) ||
                            (!isOutgoing && count >= 50))
                        ? null
                        : () => setState(() => count++),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.last_page), // Set to max
                    tooltip: 'Set to Max',
                    onPressed: (selectedItem == null || !isOutgoing)
                        ? null
                        : () => setState(() {
                            count = selectedItem!['quantity'] ?? 0;
                          }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  (selectedItem == null || isSubmitting || isLoadingItems)
                  ? null
                  : submitNotification,
              child: (isSubmitting || isLoadingItems)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Notification'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

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
