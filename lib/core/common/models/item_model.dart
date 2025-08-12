import '../../constants/constants.dart';

class ItemModel {
  final String id;
  final String name;
  final String warehouseId;
  final String locationId;
  final int quantity;
  final String updatedAt;
  final String? syncedAt;

  ItemModel({
    required this.id,
    required this.name,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    required this.updatedAt,
    this.syncedAt,
  });

  // Construct from Firestore/JSON
  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json[YStrings.colId] as String,
      name: json[YStrings.colName] as String,
      warehouseId: json[YStrings.colWarehouseId] as String,
      locationId: json[YStrings.colLocationId] as String,
      quantity: json[YStrings.colQuantity] as int,
      updatedAt: json[YStrings.colUpdatedAt] as String,
      syncedAt: json[YStrings.colSyncedAt] as String?,
    );
  }

  // Construct from local DB (SQLite)
  factory ItemModel.fromDb(Map<String, dynamic> map) {
    return ItemModel(
      id: map[YStrings.colId] as String,
      name: map[YStrings.colName] as String,
      warehouseId: map[YStrings.colWarehouseId] as String,
      locationId: map[YStrings.colLocationId] as String,
      quantity: map[YStrings.colQuantity] as int,
      updatedAt: map[YStrings.colUpdatedAt] as String,
      syncedAt: map[YStrings.colSyncedAt] as String?,
    );
  }

  // Convert to DB/Firestore Map
  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colName: name,
      YStrings.colWarehouseId: warehouseId,
      YStrings.colLocationId: locationId,
      YStrings.colQuantity: quantity,
      YStrings.colUpdatedAt: updatedAt,
      YStrings.colSyncedAt: syncedAt,
    };
  }

  factory ItemModel.empty() {
    return ItemModel(
      id: '',
      name: '',
      warehouseId: '',
      locationId: '',
      quantity: 0,
      updatedAt: '',
      syncedAt: null,
    );
  }

  ItemModel copyWith({
    String? id,
    String? name,
    String? warehouseId,
    String? locationId,
    int? quantity,
    String? updatedAt,
    String? syncedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      warehouseId: warehouseId ?? this.warehouseId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Helper: check if this record is synced
  bool get isSynced => syncedAt != null;
}
