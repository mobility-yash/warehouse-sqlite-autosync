import '../../constants/constants.dart';

class ItemModel {
  final String id;
  final String name;
  final String warehouseId;
  final String locationId;
  final int quantity;
  final String updatedAt;
  final bool synced;

  ItemModel({
    required this.id,
    required this.name,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    required this.updatedAt,
    required this.synced,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json[YStrings.colId] as String,
      name: json[YStrings.colName] as String,
      warehouseId: json[YStrings.colWarehouseId] as String,
      locationId: json[YStrings.colLocationId] as String,
      quantity: json[YStrings.colQuantity] as int,
      updatedAt: json[YStrings.colUpdatedAt] as String,
      synced: (json[YStrings.colSynced] ?? 0) == 1,
    );
  }

  factory ItemModel.fromDb(Map<String, dynamic> map) {
    return ItemModel(
      id: map[YStrings.colId],
      name: map[YStrings.colName],
      warehouseId: map[YStrings.colWarehouseId],
      locationId: map[YStrings.colLocationId],
      quantity: map[YStrings.colQuantity],
      updatedAt: map[YStrings.colUpdatedAt],
      synced: (map[YStrings.colSynced] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colName: name,
      YStrings.colWarehouseId: warehouseId,
      YStrings.colLocationId: locationId,
      YStrings.colQuantity: quantity,
      YStrings.colUpdatedAt: updatedAt,
      YStrings.colSynced: synced ? 1 : 0,
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
      synced: false,
    );
  }

  ItemModel copyWith({
    String? id,
    String? name,
    String? warehouseId,
    String? locationId,
    int? quantity,
    String? updatedAt,
    bool? synced,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      warehouseId: warehouseId ?? this.warehouseId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
