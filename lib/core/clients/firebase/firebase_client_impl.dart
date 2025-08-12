import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

import 'firebase_client.dart';

class FirebaseClientImpl implements FirebaseClient {
  final FirebaseFirestore _firestore;

  FirebaseClientImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ----------------------
  // Helper: parse DateTime from stored field (Timestamp or ISO string)
  // ----------------------
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.parse(value);
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] _parseDateTime error: $e');
      debugPrint(st.toString());
    }
    return null;
  }

  // ----------------------
  // LOCATIONS
  // ----------------------
  @override
  Future<List<DocumentSnapshot>> fetchLocations() async {
    final snapshot = await _firestore.collection(YStrings.locations).get();
    final sorted = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return sorted;
  }

  // ----------------------
  // WAREHOUSES
  // ----------------------
  @override
  Future<List<DocumentSnapshot>> fetchWarehouses(String locationId) async {
    final snapshot = await _firestore
        .collection(YStrings.warehouses)
        .where(YStrings.colLocationId, isEqualTo: locationId)
        .get();
    final sorted = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return sorted;
  }

  // ----------------------
  // ITEMS
  // ----------------------
  @override
  Future<List<DocumentSnapshot>> fetchItems(String warehouseId) async {
    final snapshot = await _firestore
        .collection(YStrings.items)
        .where(YStrings.colWarehouseId, isEqualTo: warehouseId)
        .get();
    final sorted = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return sorted;
  }

  @override
  Future<DocumentSnapshot?> getItemById(String itemId) async {
    final doc = await _firestore.collection(YStrings.items).doc(itemId).get();
    return doc.exists ? doc : null;
  }

  // ----------------------
  // ITEMS - SYNC to Firestore
  // ----------------------
  @override
  Future<void> saveItem(ItemModel item) async {
    debugPrint('[FirebaseClientImpl] Saving item to Firestore: ${item.id}');
    final docRef = _firestore.collection(YStrings.items).doc(item.id);
    await docRef.set(item.toMap(), SetOptions(merge: true));
  }

  // ----------------------
  // NOTIFICATIONS
  // ----------------------
  @override
  Future<void> submitNotification({
    required String type,
    required String itemId,
    required int count,
    required String warehouseId,
    required String locationId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final itemRef = _firestore.collection(YStrings.items).doc(itemId);
      final snapshot = await transaction.get(itemRef);

      if (!snapshot.exists) throw Exception('Item not found.');
      final data = snapshot.data() ?? {};
      int currentQty = data[YStrings.colQuantity] ?? 0;
      int newQty = currentQty;

      if (type == YStrings.transactionOutgoing) {
        if (count > currentQty) {
          throw Exception(YStrings.errNotEnoughStock);
        }
        newQty -= count;
      } else {
        newQty += count;
      }

      transaction.update(itemRef, {
        YStrings.colQuantity: newQty,
        YStrings.colUpdatedAt: DateTime.now().toIso8601String(),
      });

      final notificationRef = _firestore
          .collection(YStrings.notifications)
          .doc();
      transaction.set(notificationRef, {
        YStrings.colId: const Uuid().v4(),
        YStrings.colType: type,
        YStrings.colItemId: itemId,
        YStrings.colCount: count,
        YStrings.colWarehouseId: warehouseId,
        YStrings.colLocationId: locationId,
        YStrings.colUpdatedAt: DateTime.now().toIso8601String(),
        YStrings.colSynced: 1,
      });
    });
  }

  @override
  Future<void> saveNotification(NotificationModel notif) async {
    debugPrint(
      '[FirebaseClientImpl] Saving notification to Firestore: ${notif.id}',
    );
    await _firestore
        .collection(YStrings.notifications)
        .doc(notif.id)
        .set(notif.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<QuerySnapshot> listenNotifications() {
    return _firestore
        .collection(YStrings.notifications)
        .orderBy(YStrings.colUpdatedAt, descending: true)
        .snapshots();
  }

  // ----------------------
  // UTILS
  // ----------------------
  @override
  Future<String> getNameById(String collection, String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      return doc.exists
          ? (doc.data()?[YStrings.colName] ?? 'Unknown')
          : 'Unknown';
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] getNameById error: $e');
      debugPrint(st.toString());
      return 'Unknown';
    }
  }

  // ----------------------
  // SYNC METADATA
  // ----------------------
  @override
  Future<Map<String, DateTime?>> fetchSyncMetadata() async {
    final Map<String, DateTime?> result = {};
    try {
      final snapshot = await _firestore.collection(YStrings.syncMetadata).get();
      for (final doc in snapshot.docs) {
        final key = doc.id.isNotEmpty
            ? doc.id
            : (doc.data()[YStrings.colEntity] ?? '');
        final lastUpdatedRaw = doc.data()[YStrings.colLastUpdatedAt];
        result[key] = _parseDateTime(lastUpdatedRaw);
      }
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] fetchSyncMetadata error: $e');
      debugPrint(st.toString());
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTableData(String table) async {
    final List<Map<String, dynamic>> rows = [];
    debugPrint('[FirebaseClientImpl] Starting fetch for table: $table');

    try {
      final snapshot = await _firestore.collection(table).get();
      debugPrint(
        '[FirebaseClientImpl] Fetched ${snapshot.docs.length} docs from $table',
      );

      for (final doc in snapshot.docs) {
        final data = <String, dynamic>{}..addAll(doc.data());
        data[YStrings.colId] = doc.id;

        final updatedRaw = data[YStrings.colUpdatedAt];
        final updatedDt = _parseDateTime(updatedRaw);
        if (updatedDt != null) {
          data[YStrings.colUpdatedAt] = updatedDt.toIso8601String();
          debugPrint(
            '[FirebaseClientImpl] Parsed updatedAt for ${doc.id}: ${updatedDt.toIso8601String()}',
          );
        }
        rows.add(data);
      }

      debugPrint('[FirebaseClientImpl] Completed processing for table: $table');
      debugPrint('[FirebaseClientImpl] Total rows collected: ${rows.length}');
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] fetchTableData($table) error: $e');
      debugPrint(st.toString());
    }
    return rows;
  }

  @override
  Future<DateTime?> getTableUpdatedAt(String table) async {
    try {
      final docRef = _firestore.collection(YStrings.syncMetadata).doc(table);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        return _parseDateTime(docSnap.data()?[YStrings.colLastUpdatedAt]);
      }
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] getTableUpdatedAt($table) error: $e');
      debugPrint(st.toString());
    }
    return null;
  }

  @override
  Future<void> updateSyncMetadata(String entity, DateTime lastUpdatedAt) async {
    debugPrint(
      '[FirebaseClientImpl] updateSyncMetadata for $entity -> ${lastUpdatedAt.toIso8601String()}',
    );
    await _firestore.collection(YStrings.syncMetadata).doc(entity).set({
      YStrings.colLastUpdatedAt: lastUpdatedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }
}
