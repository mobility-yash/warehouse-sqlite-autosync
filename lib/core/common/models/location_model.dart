import '../../constants/constants.dart';

class LocationModel {
  final String id;
  final String name;
  final String address;
  final String updatedAt;

  LocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.updatedAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json[YStrings.colId] as String,
      name: json[YStrings.colName] as String,
      address: json[YStrings.colAddress] as String,
      updatedAt: json[YStrings.colUpdatedAt] as String,
    );
  }

  factory LocationModel.fromDb(Map<String, dynamic> map) {
    return LocationModel(
      id: map[YStrings.colId],
      name: map[YStrings.colName],
      address: map[YStrings.colAddress],
      updatedAt: map[YStrings.colUpdatedAt],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      YStrings.colId: id,
      YStrings.colName: name,
      YStrings.colAddress: address,
      YStrings.colUpdatedAt: updatedAt,
    };
  }

  factory LocationModel.empty() {
    return LocationModel(id: '', name: '', address: '', updatedAt: '');
  }

  LocationModel copyWith({
    String? id,
    String? name,
    String? address,
    String? updatedAt,
  }) {
    return LocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'LocationModel(id: $id, name: $name, address: $address, updatedAt: $updatedAt)';
  }
}
