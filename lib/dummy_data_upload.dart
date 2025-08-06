import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
      home: DummyDataUploader(),
    );
  }
}

class DummyDataUploader extends StatelessWidget {
  DummyDataUploader({super.key});

  final List<String> locationNames = [
    'Mumbai',
    'Pune',
    'Delhi',
    'Bengaluru',
    'Chennai',
    'Kolkata',
    'Hyderabad',
    'Jaipur',
    'Ahmedabad',
    'Surat',
  ];

  final List<String> itemNames = [
    'Rice',
    'Wheat',
    'Sugar',
    'Salt',
    'Oil',
    'Spices',
    'Tea',
    'Coffee',
    'Flour',
    'Lentils',
    'Beans',
    'Milk',
    'Butter',
    'Ghee',
    'Biscuits',
    'Soap',
    'Shampoo',
    'Toothpaste',
    'Detergent',
    'Snacks',
    'Juice',
    'Water',
  ];

  Future<void> uploadData() async {
    final firestore = FirebaseFirestore.instance;
    final now = Timestamp.now();
    final random = Random();

    List<String> locationIds = [];

    for (String locName in locationNames) {
      final locationRef = firestore.collection('locations').doc();
      await locationRef.set({
        'id': locationRef.id,
        'name': locName,
        'address': '$locName Main Street',
        'updatedAt': now,
      });
      locationIds.add(locationRef.id);

      // Generate 3–15 warehouses for each location
      int warehouseCount = 3 + random.nextInt(13); // 3 to 15
      for (int i = 0; i < warehouseCount; i++) {
        final warehouseRef = firestore.collection('warehouses').doc();
        String warehouseName = '$locName Warehouse ${i + 1}';

        await warehouseRef.set({
          'id': warehouseRef.id,
          'name': warehouseName,
          'locationId': locationRef.id,
          'address': '$warehouseName Street',
          'updatedAt': now,
        });

        // Generate 10–30 items per warehouse
        int itemCount = 10 + random.nextInt(21); // 10 to 30
        for (int j = 0; j < itemCount; j++) {
          final itemRef = firestore.collection('items').doc();
          final itemName = itemNames[random.nextInt(itemNames.length)];
          final quantity = 10 + random.nextInt(90); // 10 to 100

          await itemRef.set({
            'id': itemRef.id,
            'name': itemName,
            'warehouseId': warehouseRef.id,
            'locationId': locationRef.id,
            'quantity': quantity,
            'updatedAt': now,
          });

          // Optionally add 1–2 notifications
          int notificationCount = random.nextInt(2); // 0 or 1
          for (int k = 0; k < notificationCount; k++) {
            final notificationRef = firestore.collection('notifications').doc();
            final type = random.nextBool() ? 'incoming' : 'outgoing';
            final delta = 1 + random.nextInt(10);

            await notificationRef.set({
              'id': notificationRef.id,
              'type': type,
              'itemId': itemRef.id,
              'count': delta,
              'warehouseId': warehouseRef.id,
              'locationId': locationRef.id,
              'updatedAt': now,
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Seeder')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await uploadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Realistic Data Uploaded!')),
            );
          },
          child: const Text('Generate & Upload Real Data'),
        ),
      ),
    );
  }
}
