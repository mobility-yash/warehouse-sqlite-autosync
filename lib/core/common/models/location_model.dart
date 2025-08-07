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
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  factory LocationModel.fromDb(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'address': address, 'updatedAt': updatedAt};
  }
}
