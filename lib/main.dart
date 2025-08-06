import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
    final snapshot = await _firestore
        .collection('items')
        .where('warehouseId', isEqualTo: warehouseId)
        .get();
    final sorted = snapshot.docs
      ..sort((a, b) => a['name'].compareTo(b['name']));
    setState(() {
      items = sorted;
      selectedItemId = null;
      selectedItem = null;
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

    final itemDoc = selectedItem!;
    final currentQty = itemDoc['quantity'] ?? 0;

    if (notificationType == 'outgoing') {
      if (count > currentQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough stock for outgoing!')),
        );
        return;
      }
      await _firestore.collection('items').doc(selectedItemId).update({
        'quantity': currentQty - count,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      await _firestore.collection('items').doc(selectedItemId).update({
        'quantity': currentQty + count,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await _firestore.collection('notifications').add({
      'id': const Uuid().v4(),
      'type': notificationType,
      'itemId': selectedItemId,
      'count': count,
      'warehouseId': selectedWarehouseId,
      'locationId': selectedLocationId,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notification submitted.')));
  }

  @override
  Widget build(BuildContext context) {
    final currentItemQty = selectedItem != null
        ? selectedItem!['quantity'] ?? 0
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
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

            if (selectedItem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Current Quantity: ${selectedItem!['quantity']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                const Text('Quantity:'),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: (selectedItem == null || count <= 1)
                      ? null
                      : () => setState(() => count--),
                ),
                Text('$count'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed:
                      (selectedItem == null ||
                          (isOutgoing &&
                              count >= (selectedItem!['quantity'] ?? 0)) ||
                          (!isOutgoing && count >= 50))
                      ? null
                      : () => setState(() => count++),
                ),
              ],
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: selectedItem == null ? null : submitNotification,
              child: const Text('Submit Notification'),
            ),
          ],
        ),
      ),
    );
  }
}
