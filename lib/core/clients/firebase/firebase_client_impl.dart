import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

import 'firebase_client.dart';

class FirebaseClientImpl implements FirebaseClient {
  final FirebaseFirestore _firestore;
  FirebaseClientImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is DateTime) return value;
    } catch (_) {}
    return null;
  }

  // ================= LOCATIONS =================
  @override
  Future<List<DocumentSnapshot>> fetchLocations({
    DateTime? updatedAfter,
  }) async {
    Query query = _firestore.collection(YStrings.locations);
    if (updatedAfter != null) {
      query = query.where(
        YStrings.colUpdatedAt,
        isGreaterThan: updatedAfter.toIso8601String(),
      );
    }
    final snapshot = await query.get();
    final docs = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return docs;
  }

  // ================= WAREHOUSES =================
  @override
  Future<List<DocumentSnapshot>> fetchWarehouses(
    String locationId, {
    DateTime? updatedAfter,
  }) async {
    Query query = _firestore
        .collection(YStrings.warehouses)
        .where(YStrings.colLocationId, isEqualTo: locationId);
    if (updatedAfter != null) {
      query = query.where(
        YStrings.colUpdatedAt,
        isGreaterThan: updatedAfter.toIso8601String(),
      );
    }
    final snapshot = await query.get();
    final docs = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return docs;
  }

  // ================= ITEMS =================
  @override
  Future<List<DocumentSnapshot>> fetchItems(
    String warehouseId, {
    DateTime? updatedAfter,
  }) async {
    Query query = _firestore
        .collection(YStrings.items)
        .where(YStrings.colWarehouseId, isEqualTo: warehouseId);
    if (updatedAfter != null) {
      query = query.where(
        YStrings.colUpdatedAt,
        isGreaterThan: updatedAfter.toIso8601String(),
      );
    }
    final snapshot = await query.get();
    final docs = snapshot.docs
      ..sort(
        (a, b) =>
            (a[YStrings.colName] ?? '').compareTo(b[YStrings.colName] ?? ''),
      );
    return docs;
  }

  @override
  Future<DocumentSnapshot?> getItemById(String itemId) async {
    final doc = await _firestore.collection(YStrings.items).doc(itemId).get();
    return doc.exists ? doc : null;
  }

  @override
  Future<void> saveItem(ItemModel item) async {
    final now = DateTime.now().toIso8601String();
    await _firestore.collection(YStrings.items).doc(item.id).set({
      ...item.toMap(),
      YStrings.colUpdatedAt: now,
      YStrings.colSyncedAt: now,
    }, SetOptions(merge: true));
  }

  // ================= NOTIFICATIONS =================
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
        if (count > currentQty) throw Exception(YStrings.errNotEnoughStock);
        newQty -= count;
      } else {
        newQty += count;
      }

      transaction.update(itemRef, {
        YStrings.colQuantity: newQty,
        YStrings.colUpdatedAt: DateTime.now().toIso8601String(),
        YStrings.colSyncedAt: DateTime.now().toIso8601String(),
      });

      final notifId = const Uuid().v4();
      transaction
          .set(_firestore.collection(YStrings.notifications).doc(notifId), {
            YStrings.colId: notifId,
            YStrings.colType: type,
            YStrings.colItemId: itemId,
            YStrings.colCount: count,
            YStrings.colWarehouseId: warehouseId,
            YStrings.colLocationId: locationId,
            YStrings.colUpdatedAt: DateTime.now().toIso8601String(),
            YStrings.colSyncedAt: DateTime.now().toIso8601String(),
          });
    });
  }

  @override
  Future<void> saveNotification(NotificationModel notif) async {
    final now = DateTime.now().toIso8601String();
    await _firestore.collection(YStrings.notifications).doc(notif.id).set({
      ...notif.toMap(),
      YStrings.colUpdatedAt: now,
      YStrings.colSyncedAt: now,
    }, SetOptions(merge: true));
  }

  @override
  Stream<QuerySnapshot> listenNotifications() {
    return _firestore
        .collection(YStrings.notifications)
        .orderBy(YStrings.colUpdatedAt, descending: true)
        .snapshots();
  }

  @override
  Future<String> getNameById(String collection, String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      return doc.exists
          ? (doc.data()?[YStrings.colName] ?? 'Unknown')
          : 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ================= SYNC METADATA =================
  @override
  Future<Map<String, DateTime?>> fetchSyncMetadata() async {
    final Map<String, DateTime?> result = {};
    final snapshot = await _firestore.collection(YStrings.syncMetadata).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      result[doc.id] = _parseDateTime(data[YStrings.colLastTableUpdatedAt]);
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTableData(
    String table, {
    DateTime? updatedAfter,
  }) async {
    Query query = _firestore.collection(table);
    if (updatedAfter != null) {
      query = query.where(
        YStrings.colUpdatedAt,
        isGreaterThan: updatedAfter.toIso8601String(),
      );
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map<Map<String, dynamic>>(
          (doc) => {
            ...doc.data() as Map<String, dynamic>,
            YStrings.colId: doc.id,
            YStrings.colUpdatedAt: _parseDateTime(
              doc[YStrings.colUpdatedAt],
            )?.toIso8601String(),
            if (doc[YStrings.colSyncedAt] != null)
              YStrings.colSyncedAt: _parseDateTime(
                doc[YStrings.colSyncedAt],
              )?.toIso8601String(),
          },
        )
        .toList();
  }

  @override
  Future<void> updateSyncMetadata({
    required String entity,
    required DateTime lastTableUpdatedAt,
  }) async {
    await _firestore.collection(YStrings.syncMetadata).doc(entity).set({
      YStrings.colLastTableUpdatedAt: lastTableUpdatedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }
}
