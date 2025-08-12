import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';

abstract class FirebaseClient {
  Future<List<DocumentSnapshot>> fetchLocations({DateTime? updatedAfter});
  Future<List<DocumentSnapshot>> fetchWarehouses(
    String locationId, {
    DateTime? updatedAfter,
  });
  Future<List<DocumentSnapshot>> fetchItems(
    String warehouseId, {
    DateTime? updatedAfter,
  });
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

  Future<Map<String, DateTime?>>
  fetchSyncMetadata(); // {entity: lastTableUpdatedAt}
  Future<List<Map<String, dynamic>>> fetchTableData(
    String table, {
    DateTime? updatedAfter,
  });
  Future<void> updateSyncMetadata({
    required String entity,
    required DateTime lastTableUpdatedAt,
  });
}
