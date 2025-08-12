import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';

abstract class FirebaseClient {
  Future<List<DocumentSnapshot>> fetchLocations();
  Future<List<DocumentSnapshot>> fetchWarehouses(String locationId);
  Future<List<DocumentSnapshot>> fetchItems(String warehouseId);
  Future<DocumentSnapshot?> getItemById(String itemId);

  Future<void> saveItem(ItemModel item);

  Future<void> submitNotification({
    required String type,
    required String itemId,
    required int count,
    required String warehouseId,
    required String locationId,
  });
  Future<void> saveNotification(NotificationModel notif);

  Stream<QuerySnapshot> listenNotifications();
  Future<String> getNameById(String collection, String id);

  Future<Map<String, DateTime?>> fetchSyncMetadata();
  Future<List<Map<String, dynamic>>> fetchTableData(String table);
  Future<DateTime?> getTableUpdatedAt(String table);
  Future<void> updateSyncMetadata(String entity, DateTime lastUpdatedAt);
}
