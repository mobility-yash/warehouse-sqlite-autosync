import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirebaseClient {
  Future<List<DocumentSnapshot>> fetchLocations();
  Future<List<DocumentSnapshot>> fetchWarehouses(String locationId);
  Future<List<DocumentSnapshot>> fetchItems(String warehouseId);
  Future<DocumentSnapshot?> getItemById(String itemId);
  Future<void> submitNotification({
    required String type,
    required String itemId,
    required int count,
    required String warehouseId,
    required String locationId,
  });

  Stream<QuerySnapshot> listenNotifications();
  Future<String> getNameById(String collection, String id);

  Future<Map<String, DateTime?>> fetchSyncMetadata();
  Future<List<Map<String, dynamic>>> fetchTableData(String table);
  Future<DateTime?> getTableUpdatedAt(String table);
}
