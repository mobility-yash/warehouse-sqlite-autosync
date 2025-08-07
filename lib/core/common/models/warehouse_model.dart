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
      id: json['id'] as String,
      name: json['name'] as String,
      locationId: json['locationId'] as String,
      address: json['address'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  factory WarehouseModel.fromDb(Map<String, dynamic> map) {
    return WarehouseModel(
      id: map['id'],
      name: map['name'],
      locationId: map['locationId'],
      address: map['address'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'locationId': locationId,
      'address': address,
      'updatedAt': updatedAt,
    };
  }
}
