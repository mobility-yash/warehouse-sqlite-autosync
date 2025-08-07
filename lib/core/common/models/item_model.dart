class ItemModel {
  final String id;
  final String name;
  final String warehouseId;
  final String locationId;
  final int quantity;
  final String updatedAt;

  ItemModel({
    required this.id,
    required this.name,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    required this.updatedAt,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      warehouseId: json['warehouseId'] as String,
      locationId: json['locationId'] as String,
      quantity: json['quantity'] as int,
      updatedAt: json['updatedAt'] as String,
    );
  }

  factory ItemModel.fromDb(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'],
      name: map['name'],
      warehouseId: map['warehouseId'],
      locationId: map['locationId'],
      quantity: map['quantity'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'warehouseId': warehouseId,
      'locationId': locationId,
      'quantity': quantity,
      'updatedAt': updatedAt,
    };
  }
}
