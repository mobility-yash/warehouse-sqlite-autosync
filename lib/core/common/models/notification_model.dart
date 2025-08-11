import '../../constants/constants.dart';

class NotificationModel {
  final String id;
  final String type;
  final String itemId;
  final int count;
  final String warehouseId;
  final String locationId;
  final String updatedAt;
  final bool synced;

  NotificationModel({
    required this.id,
    required this.type,
    required this.itemId,
    required this.count,
    required this.warehouseId,
    required this.locationId,
    required this.updatedAt,
    required this.synced,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json[YStrings.colId] as String,
      type: json[YStrings.colType] as String,
      itemId: json[YStrings.colItemId] as String,
      count: json[YStrings.colCount] as int,
      warehouseId: json[YStrings.colWarehouseId] as String,
      locationId: json[YStrings.colLocationId] as String,
      updatedAt: json[YStrings.colUpdatedAt] as String,
      synced: json[YStrings.colSynced] == 1,
    );
  }

  factory NotificationModel.fromDb(Map<String, dynamic> map) {
    return NotificationModel(
      id: map[YStrings.colId],
      type: map[YStrings.colType],
      itemId: map[YStrings.colItemId],
      count: map[YStrings.colCount],
      warehouseId: map[YStrings.colWarehouseId],
      locationId: map[YStrings.colLocationId],
      updatedAt: map[YStrings.colUpdatedAt],
      synced: map[YStrings.colSynced] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colType: type,
      YStrings.colItemId: itemId,
      YStrings.colCount: count,
      YStrings.colWarehouseId: warehouseId,
      YStrings.colLocationId: locationId,
      YStrings.colUpdatedAt: updatedAt,
      YStrings.colSynced: synced ? 1 : 0,
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
      synced: false,
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
    bool? synced,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      count: count ?? this.count,
      warehouseId: warehouseId ?? this.warehouseId,
      locationId: locationId ?? this.locationId,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
