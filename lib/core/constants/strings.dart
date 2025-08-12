part of 'constants.dart';

class YStrings {
  YStrings._();

  // -------------------------
  // Preference keys
  // -------------------------
  static const firstTimeLaunch = 'first_time_launch';
  static const lastInitSyncSuccess = 'last_init_sync_success';
  static const syncStatusPrefix = 'sync_status_';

  // -------------------------
  // Table / Collection names
  // -------------------------
  static const locations = 'locations';
  static const warehouses = 'warehouses';
  static const items = 'items';
  static const notifications = 'notifications';
  static const syncMetadata = 'sync_metadata';

  // -------------------------
  // Common column / field names
  // -------------------------
  static const colId = 'id';
  static const colName = 'name';
  static const colAddress = 'address';
  static const colUpdatedAt = 'updatedAt';
  static const colSyncedAt = 'syncedAt';
  static const colLocationId = 'locationId';
  static const colWarehouseId = 'warehouseId';
  static const colQuantity = 'quantity';
  static const colType = 'type';
  static const colItemId = 'itemId';
  static const colCount = 'count';
  static const colEntity = 'entity';
  static const colLastLocalUpdatedAt = 'lastLocalUpdatedAt';
  static const colLastRemoteUpdatedAt = 'lastRemoteUpdatedAt';
  static const colLastTableUpdatedAt = 'lastTableUpdatedAt';

  // -------------------------
  // Firebase specific keys
  // -------------------------
  static const firestoreDocId = 'docId';
  static const firestoreCreatedAt = 'createdAt';
  static const firestoreUpdatedAt = 'updatedAt';
  static const firestoreStatus = 'status';
  static const firestoreData = 'data';
  static const firestoreUserId = 'userId';

  // -------------------------
  // Transaction types
  // -------------------------
  static const transactionOutgoing = 'outgoing';
  static const transactionIncoming = 'incoming';

  // -------------------------
  // Error messages
  // -------------------------
  static const errNotEnoughStock = 'Not enough stock for outgoing!';
}
