import '../../constants/constants.dart';

class NotificationModel {
  final String id;
  final String type;
  final String itemId;
  final int count;
  final String warehouseId;
  final String locationId;
  final String updatedAt;
  final String? syncedAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.itemId,
    required this.count,
    required this.warehouseId,
    required this.locationId,
    required this.updatedAt,
    this.syncedAt,
  });

  /// Build from Firestore/remote JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json[YStrings.colId] as String,
      type: json[YStrings.colType] as String,
      itemId: json[YStrings.colItemId] as String,
      count: json[YStrings.colCount] as int,
      warehouseId: json[YStrings.colWarehouseId] as String,
      locationId: json[YStrings.colLocationId] as String,
      updatedAt: json[YStrings.colUpdatedAt] as String,
      syncedAt: json[YStrings.colSyncedAt] as String?,
    );
  }

  /// Build from local SQLite DB map
  factory NotificationModel.fromDb(Map<String, dynamic> map) {
    return NotificationModel(
      id: map[YStrings.colId] as String,
      type: map[YStrings.colType] as String,
      itemId: map[YStrings.colItemId] as String,
      count: map[YStrings.colCount] as int,
      warehouseId: map[YStrings.colWarehouseId] as String,
      locationId: map[YStrings.colLocationId] as String,
      updatedAt: map[YStrings.colUpdatedAt] as String,
      syncedAt: map[YStrings.colSyncedAt] as String?,
    );
  }

  /// Convert to a map for saving to DB or Firestore
  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colType: type,
      YStrings.colItemId: itemId,
      YStrings.colCount: count,
      YStrings.colWarehouseId: warehouseId,
      YStrings.colLocationId: locationId,
      YStrings.colUpdatedAt: updatedAt,
      YStrings.colSyncedAt: syncedAt,
    };
  }

  factory NotificationModel.empty() {
    return NotificationModel(
      id: '',
      type: '',
      itemId: '',
      count: 0,
      warehouseId: '',
      locationId: '',
      updatedAt: '',
      syncedAt: null,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? type,
    String? itemId,
    int? count,
    String? warehouseId,
    String? locationId,
    String? updatedAt,
    String? syncedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      count: count ?? this.count,
      warehouseId: warehouseId ?? this.warehouseId,
      locationId: locationId ?? this.locationId,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Quick check if this notification is already synced
  bool get isSynced => syncedAt != null;
}
