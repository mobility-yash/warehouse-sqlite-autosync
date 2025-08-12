import 'package:sqflite/sqflite.dart';
import 'package:warehouse_data_autosync/core/common/models/item_model.dart';
import 'package:warehouse_data_autosync/core/common/models/location_model.dart';
import 'package:warehouse_data_autosync/core/common/models/notification_model.dart';
import 'package:warehouse_data_autosync/core/common/models/sync_metadata_model.dart';
import 'package:warehouse_data_autosync/core/common/models/warehouse_model.dart';

abstract class DatabaseClient {
  Future<Database> get database;

  // ===== Items =====
  Future<void> insertItems(List<ItemModel> items);
  Future<List<ItemModel>> getUnsyncedItems();
  Future<void> markItemsAsSynced(List<String> ids);
  Future<List<ItemModel>> getItemsByWarehouseId(String warehouseId);
  Future<bool> isItemsTableNotEmpty();
  Future<void> clearItems();

  // ===== Locations =====
  Future<void> insertLocations(List<LocationModel> locations);
  Future<List<LocationModel>> getLocations();
  Future<bool> isLocationsTableNotEmpty();
  Future<void> clearLocations();

  // ===== Warehouses =====
  Future<void> insertWarehouses(List<WarehouseModel> warehouses);
  Future<List<WarehouseModel>> getWarehousesByLocationId(String locationId);
  Future<bool> isWarehousesTableNotEmpty();
  Future<void> clearWarehouses();

  // ===== Notifications =====
  Future<List<NotificationModel>> getNotifications();
  Future<void> insertNotifications(List<NotificationModel> notifications);
  Future<List<NotificationModel>>
  getUnsyncedNotifications(); // colSyncedAt == null
  Future<void> markNotificationsAsSynced(List<String> ids);
  Future<bool> isNotificationsTableNotEmpty();
  Future<void> clearNotifications();

  // ===== Sync metadata (bidirectional sync support) =====
  Future<void> insertInitialSyncMetadata();

  // Local-only change
  Future<void> updateLastLocalUpdatedAt({
    required String entity,
    required String lastLocalUpdatedAt,
  });

  // Remote-only change
  Future<void> updateLastRemoteUpdatedAt({
    required String entity,
    required String lastRemoteUpdatedAt,
  });

  // Both after full sync
  Future<void> updateBothLocalAndRemoteTimestamps({
    required String entity,
    required String updatedAt,
  });

  Future<SyncMetadataModel?> getSyncMetadata(String entity);
  Future<bool> isSyncMetadataTableNotEmpty();
  Future<void> clearSyncMetadata();

  // Helper methods for specific tables (optional, can call the above methods directly)
  Future<void> updateLocationsSync(String lastUpdatedAt);
  Future<void> updateWarehousesSync(String lastUpdatedAt);
  Future<void> updateItemsSync(String lastUpdatedAt);
  Future<void> updateNotificationsSync(String lastUpdatedAt);

  // Utilities
  Future<Map<String, SyncMetadataModel>> getAllSyncMetadata();
  Future<void> insertOrUpdateTable(
    String table,
    List<Map<String, dynamic>> data,
  );
}
