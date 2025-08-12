import '../../constants/constants.dart';

class WarehouseModel {
  final String id;
  final String name;
  final String locationId;
  final String address;
  final String updatedAt;

  WarehouseModel({
    required this.id,
    required this.name,
    required this.locationId,
    required this.address,
    required this.updatedAt,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json[YStrings.colId] as String,
      name: json[YStrings.colName] as String,
      locationId: json[YStrings.colLocationId] as String,
      address: json[YStrings.colAddress] as String,
      updatedAt: json[YStrings.colUpdatedAt] as String,
    );
  }

  factory WarehouseModel.fromDb(Map<String, dynamic> map) {
    return WarehouseModel(
      id: map[YStrings.colId],
      name: map[YStrings.colName],
      locationId: map[YStrings.colLocationId],
      address: map[YStrings.colAddress],
      updatedAt: map[YStrings.colUpdatedAt],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colName: name,
      YStrings.colLocationId: locationId,
      YStrings.colAddress: address,
      YStrings.colUpdatedAt: updatedAt,
    };
  }

  factory WarehouseModel.empty() {
    return WarehouseModel(
      id: '',
      name: '',
      locationId: '',
      address: '',
      updatedAt: '',
    );
  }

  WarehouseModel copyWith({
    String? id,
    String? name,
    String? locationId,
    String? address,
    String? updatedAt,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      locationId: locationId ?? this.locationId,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
