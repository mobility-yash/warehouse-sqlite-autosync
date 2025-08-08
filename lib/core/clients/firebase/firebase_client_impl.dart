import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
    final snapshot = await _firestore.collection('locations').get();
    final sorted = snapshot.docs
      ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return sorted;
  }

  // ----------------------
  // WAREHOUSES
  // ----------------------
  @override
  Future<List<DocumentSnapshot>> fetchWarehouses(String locationId) async {
    final snapshot = await _firestore
        .collection('warehouses')
        .where('locationId', isEqualTo: locationId)
        .get();
    final sorted = snapshot.docs
      ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return sorted;
  }

  // ----------------------
  // ITEMS
  // ----------------------
  @override
  Future<List<DocumentSnapshot>> fetchItems(String warehouseId) async {
    final snapshot = await _firestore
        .collection('items')
        .where('warehouseId', isEqualTo: warehouseId)
        .get();
    final sorted = snapshot.docs
      ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return sorted;
  }

  @override
  Future<DocumentSnapshot?> getItemById(String itemId) async {
    final doc = await _firestore.collection('items').doc(itemId).get();
    return doc.exists ? doc : null;
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
      final itemRef = _firestore.collection('items').doc(itemId);
      final snapshot = await transaction.get(itemRef);

      if (!snapshot.exists) throw Exception('Item not found.');

      final data = snapshot.data()!;
      int currentQty = data['quantity'] ?? 0;
      int newQty = currentQty;

      if (type == 'outgoing') {
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
        'type': type,
        'itemId': itemId,
        'count': count,
        'warehouseId': warehouseId,
        'locationId': locationId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Stream<QuerySnapshot> listenNotifications() {
    return _firestore
        .collection('notifications')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ----------------------
  // UTILS
  // ----------------------
  @override
  Future<String> getNameById(String collection, String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Unknown') : 'Unknown';
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] getNameById error: $e');
      debugPrint(st.toString());
      return 'Unknown';
    }
  }

  // ----------------------
  // SYNC-RELATED METHODS (new)
  // ----------------------

  /// Fetch the whole `sync_metadata` collection from Firestore and return
  /// a map: { 'locations': DateTime?, 'warehouses': DateTime?, ... }
  @override
  Future<Map<String, DateTime?>> fetchSyncMetadata() async {
    final Map<String, DateTime?> result = {};
    try {
      final snapshot = await _firestore.collection('sync_metadata').get();
      for (final doc in snapshot.docs) {
        // Prefer using doc id as key; fallback to field 'entity'
        final key = (doc.id.isNotEmpty) ? doc.id : (doc.data()['entity'] ?? '');
        final lastUpdatedRaw = doc.data()['lastUpdatedAt'];
        result[key] = _parseDateTime(lastUpdatedRaw);
      }
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] fetchSyncMetadata error: $e');
      debugPrint(st.toString());
    }
    return result;
  }

  /// Fetch all documents for the given collection name and return list of maps.
  /// Each map will contain doc fields plus `id` key with the document id.
  @override
  Future<List<Map<String, dynamic>>> fetchTableData(String table) async {
    final List<Map<String, dynamic>> rows = [];
    try {
      final snapshot = await _firestore.collection(table).get();
      for (final doc in snapshot.docs) {
        final data = <String, dynamic>{};
        data.addAll(doc.data());
        data['id'] = doc.id;
        // normalize updatedAt to ISO string if Timestamp
        final updatedRaw = data['updatedAt'];
        final updatedDt = _parseDateTime(updatedRaw);
        if (updatedDt != null) data['updatedAt'] = updatedDt.toIso8601String();
        rows.add(data);
      }
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] fetchTableData($table) error: $e');
      debugPrint(st.toString());
    }
    return rows;
  }

  /// Get the server's lastUpdatedAt for a specific table from `sync_metadata`.
  /// Tries document ID == table first, then falls back to querying by 'entity' field.
  @override
  Future<DateTime?> getTableUpdatedAt(String table) async {
    try {
      // Try doc with id == table
      final docRef = _firestore.collection('sync_metadata').doc(table);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        return _parseDateTime(docSnap.data()!['lastUpdatedAt']);
      }

      // Fallback: query where entity == table
      final query = await _firestore
          .collection('sync_metadata')
          .where('entity', isEqualTo: table)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final d = query.docs.first;
        return _parseDateTime(d.data()['lastUpdatedAt']);
      }
    } catch (e, st) {
      debugPrint('[FirebaseClientImpl] getTableUpdatedAt($table) error: $e');
      debugPrint(st.toString());
    }
    return null;
  }
}
