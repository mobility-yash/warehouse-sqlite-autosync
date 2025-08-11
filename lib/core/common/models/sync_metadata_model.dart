import '../../constants/constants.dart';

class SyncMetadataModel {
  final String entity;
  final String lastUpdatedAt;

  SyncMetadataModel({required this.entity, required this.lastUpdatedAt});

  factory SyncMetadataModel.fromDb(Map<String, dynamic> map) {
    return SyncMetadataModel(
      entity: map[YStrings.colEntity],
      lastUpdatedAt: map[YStrings.colLastUpdatedAt],
    );
  }

  factory SyncMetadataModel.fromJson(Map<String, dynamic> json) {
    return SyncMetadataModel(
      entity: json[YStrings.colEntity] as String,
      lastUpdatedAt: json[YStrings.colLastUpdatedAt] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      YStrings.colEntity: entity,
      YStrings.colLastUpdatedAt: lastUpdatedAt,
    };
  }

  factory SyncMetadataModel.empty() {
    return SyncMetadataModel(entity: '', lastUpdatedAt: '');
  }

  SyncMetadataModel copyWith({String? entity, String? lastUpdatedAt}) {
    return SyncMetadataModel(
      entity: entity ?? this.entity,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
