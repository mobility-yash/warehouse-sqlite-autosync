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
      id: json['id'] as String,
      type: json['type'] as String,
      itemId: json['itemId'] as String,
      count: json['count'] as int,
      warehouseId: json['warehouseId'] as String,
      locationId: json['locationId'] as String,
      updatedAt: json['updatedAt'] as String,
      synced: json['synced'] == 1,
    );
  }

  factory NotificationModel.fromDb(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      type: map['type'],
      itemId: map['itemId'],
      count: map['count'],
      warehouseId: map['warehouseId'],
      locationId: map['locationId'],
      updatedAt: map['updatedAt'],
      synced: map['synced'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'itemId': itemId,
      'count': count,
      'warehouseId': warehouseId,
      'locationId': locationId,
      'updatedAt': updatedAt,
      'synced': synced ? 1 : 0,
    };
  }
}
