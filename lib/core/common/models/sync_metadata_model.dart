class SyncMetadataModel {
  final String entity;
  final String lastUpdatedAt;

  SyncMetadataModel({required this.entity, required this.lastUpdatedAt});

  factory SyncMetadataModel.fromDb(Map<String, dynamic> map) {
    return SyncMetadataModel(
      entity: map['entity'],
      lastUpdatedAt: map['lastUpdatedAt'],
    );
  }

  factory SyncMetadataModel.fromJson(Map<String, dynamic> json) {
    return SyncMetadataModel(
      entity: json['entity'] as String,
      lastUpdatedAt: json['lastUpdatedAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'entity': entity, 'lastUpdatedAt': lastUpdatedAt};
  }
}
