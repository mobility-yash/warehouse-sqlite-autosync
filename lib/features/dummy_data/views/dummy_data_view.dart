import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class DummyDataUploaderView extends StatefulWidget {
  const DummyDataUploaderView({super.key});

  @override
  State<DummyDataUploaderView> createState() => _DummyDataUploaderViewState();
}

class _DummyDataUploaderViewState extends State<DummyDataUploaderView> {
  bool _isLoading = false;
  String _currentStep = '';
  int _completedSteps = 0;
  final int _totalSteps = 5;

  Future<void> uploadData() async {
    setState(() {
      _isLoading = true;
      _completedSteps = 0;
      _currentStep = '';
    });

    final firestore = FirebaseFirestore.instance;
    final now = Timestamp.now();
    final random = Random();

    Timestamp latestLocationUpdate = now;
    Timestamp latestWarehouseUpdate = now;
    Timestamp latestItemUpdate = now;
    Timestamp? latestNotificationUpdate;
    bool notificationAdded = false;

    // Step 1: Locations
    setState(() => _currentStep = 'Uploading locations...');
    for (String locName in YArrays.locationDummyNames) {
      final locationRef = firestore.collection(YStrings.locations).doc();
      await locationRef.set({
        YStrings.colId: locationRef.id,
        YStrings.colName: locName,
        YStrings.colAddress: '$locName Main Street',
        YStrings.colUpdatedAt: now,
      });
      latestLocationUpdate = now;

      // Warehouses for each location
      int warehouseCount = 1 + random.nextInt(3);
      for (int i = 0; i < warehouseCount; i++) {
        // Step 2: Warehouses
        setState(() => _currentStep = 'Uploading warehouses...');
        final warehouseRef = firestore.collection(YStrings.warehouses).doc();
        final name =
            '${YArrays.warehouseDummyPrefixes[random.nextInt(YArrays.warehouseDummyPrefixes.length)]} '
            '${YArrays.warehouseDummySuffixes[random.nextInt(YArrays.warehouseDummySuffixes.length)]}';

        await warehouseRef.set({
          YStrings.colId: warehouseRef.id,
          YStrings.colName: name,
          YStrings.colLocationId: locationRef.id,
          YStrings.colAddress: '$name, $locName',
          YStrings.colUpdatedAt: now,
        });
        latestWarehouseUpdate = now;

        // Items
        List<String> shuffledItems = List.from(YArrays.itemDummyNames)
          ..shuffle();
        int itemCount = 1 + random.nextInt(10);
        List<String> warehouseItems = shuffledItems.take(itemCount).toList();

        for (String itemName in warehouseItems) {
          // Step 3: Items
          setState(() => _currentStep = 'Uploading items...');
          final itemRef = firestore.collection(YStrings.items).doc();
          final quantity = 10 + random.nextInt(15);

          await itemRef.set({
            YStrings.colId: itemRef.id,
            YStrings.colName: itemName,
            YStrings.colWarehouseId: warehouseRef.id,
            YStrings.colLocationId: locationRef.id,
            YStrings.colQuantity: quantity,
            YStrings.colUpdatedAt: now,
          });
          latestItemUpdate = now;

          // Step 4: Notifications (only one)
          if (!notificationAdded) {
            setState(() => _currentStep = 'Uploading notifications...');
            final notificationRef = firestore
                .collection(YStrings.notifications)
                .doc();
            await notificationRef.set({
              YStrings.colId: notificationRef.id,
              YStrings.colType: YStrings.transactionOutgoing,
              YStrings.colItemId: itemRef.id,
              YStrings.colCount: 10,
              YStrings.colWarehouseId: warehouseRef.id,
              YStrings.colLocationId: locationRef.id,
              YStrings.colUpdatedAt: now,
            });
            latestNotificationUpdate = now;
            notificationAdded = true;
          }
        }
      }
    }
    _completedSteps = 4; // 4 data tables done

    // Step 5: Metadata
    setState(() => _currentStep = 'Updating sync metadata...');
    final metadataCollection = firestore.collection(YStrings.syncMetadata);

    await metadataCollection.doc(YStrings.locations).set({
      YStrings.colEntity: YStrings.locations,
      YStrings.colLastUpdatedAt: latestLocationUpdate,
    });
    await metadataCollection.doc(YStrings.warehouses).set({
      YStrings.colEntity: YStrings.warehouses,
      YStrings.colLastUpdatedAt: latestWarehouseUpdate,
    });
    await metadataCollection.doc(YStrings.items).set({
      YStrings.colEntity: YStrings.items,
      YStrings.colLastUpdatedAt: latestItemUpdate,
    });
    if (latestNotificationUpdate != null) {
      await metadataCollection.doc(YStrings.notifications).set({
        YStrings.colEntity: YStrings.notifications,
        YStrings.colLastUpdatedAt: latestNotificationUpdate,
      });
    }

    setState(() {
      _completedSteps = _totalSteps;
      _isLoading = false;
      _currentStep = 'All data uploaded!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Seeder')),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _currentStep,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$_completedSteps / $_totalSteps steps completed'),
                ],
              )
            : ElevatedButton(
                onPressed: uploadData,
                child: const Text('Generate & Upload Real Data'),
              ),
      ),
    );
  }
}
