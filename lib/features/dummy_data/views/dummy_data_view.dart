import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DummyDataUploaderView extends StatelessWidget {
  DummyDataUploaderView({super.key});

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

  final List<String> warehousePrefixes = [
    'Central Depot',
    'Main Storage Facility',
    'Distribution Hub',
    'Logistics Center',
    'North Block Storage',
    'Regional Stockyard',
    'Goods Handling Unit',
    'Urban Delivery Base',
    'Rural Supplies Depot',
    'Bulk Storage Area',
  ];

  final List<String> warehouseSuffixes = [
    'for Dry Goods',
    'and Packaged Food',
    'Handling Agricultural Stock',
    'Near Industrial Area',
    'Behind Main Market',
    'Close to Railway Yard',
    'Next to Wholesale Market',
    'inside Commercial Complex',
    'for Essential Commodities',
    'of FMCG Distribution',
  ];

  Future<void> uploadData() async {
    final firestore = FirebaseFirestore.instance;
    final now = Timestamp.now();
    final random = Random();

    Timestamp latestLocationUpdate = now;
    Timestamp latestWarehouseUpdate = now;
    Timestamp latestItemUpdate = now;
    Timestamp? latestNotificationUpdate;

    bool notificationAdded = false;

    for (String locName in locationNames) {
      final locationRef = firestore.collection('locations').doc();
      await locationRef.set({
        'id': locationRef.id,
        'name': locName,
        'address': '$locName Main Street',
        'updatedAt': now,
      });
      latestLocationUpdate = now;

      // Generate 1–3 warehouses
      int warehouseCount = 1 + random.nextInt(3);
      for (int i = 0; i < warehouseCount; i++) {
        final warehouseRef = firestore.collection('warehouses').doc();

        final name =
            '${warehousePrefixes[random.nextInt(warehousePrefixes.length)]} '
            '${warehouseSuffixes[random.nextInt(warehouseSuffixes.length)]}';

        await warehouseRef.set({
          'id': warehouseRef.id,
          'name': name,
          'locationId': locationRef.id,
          'address': '$name, $locName',
          'updatedAt': now,
        });
        latestWarehouseUpdate = now;

        // Pick a unique random subset of items for this warehouse
        List<String> shuffledItems = List.from(itemNames)..shuffle();
        int itemCount = 1 + random.nextInt(10); // 1 to 10 items
        List<String> warehouseItems = shuffledItems.take(itemCount).toList();

        for (String itemName in warehouseItems) {
          final itemRef = firestore.collection('items').doc();
          final quantity = 10 + random.nextInt(15); // 10 to 24

          await itemRef.set({
            'id': itemRef.id,
            'name': itemName,
            'warehouseId': warehouseRef.id,
            'locationId': locationRef.id,
            'quantity': quantity,
            'updatedAt': now,
          });
          latestItemUpdate = now;

          // Add only one notification: for first location, first warehouse, first item
          if (!notificationAdded) {
            final notificationRef = firestore.collection('notifications').doc();
            final type = 'outgoing';
            final delta = 10;

            await notificationRef.set({
              'id': notificationRef.id,
              'type': type,
              'itemId': itemRef.id,
              'count': delta,
              'warehouseId': warehouseRef.id,
              'locationId': locationRef.id,
              'updatedAt': now,
            });

            latestNotificationUpdate = now;
            notificationAdded = true;
          }
        }
      }
    }

    final metadataCollection = firestore.collection('sync_metadata');

    await metadataCollection.doc('locations').set({
      'collection': 'locations',
      'updatedAt': latestLocationUpdate,
    });

    await metadataCollection.doc('warehouses').set({
      'collection': 'warehouses',
      'updatedAt': latestWarehouseUpdate,
    });

    await metadataCollection.doc('items').set({
      'collection': 'items',
      'updatedAt': latestItemUpdate,
    });

    if (latestNotificationUpdate != null) {
      await metadataCollection.doc('notifications').set({
        'collection': 'notifications',
        'updatedAt': latestNotificationUpdate,
      });
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
