import '../../constants/constants.dart';

class SyncMetadataModel {
  final String entity;
  final String? lastLocalUpdatedAt;
  final String? lastRemoteUpdatedAt;

  SyncMetadataModel({
    required this.entity,
    this.lastLocalUpdatedAt,
    this.lastRemoteUpdatedAt,
  });

  /// From local DB row
  factory SyncMetadataModel.fromDb(Map<String, dynamic> map) {
    return SyncMetadataModel(
      entity: map[YStrings.colEntity] as String,
      lastLocalUpdatedAt: map[YStrings.colLastLocalUpdatedAt] as String?,
      lastRemoteUpdatedAt: map[YStrings.colLastRemoteUpdatedAt] as String?,
    );
  }

  /// From Firestore JSON
  factory SyncMetadataModel.fromJson(Map<String, dynamic> json) {
    return SyncMetadataModel(
      entity: json[YStrings.colEntity] as String,
      lastLocalUpdatedAt: json[YStrings.colLastLocalUpdatedAt] as String?,
      lastRemoteUpdatedAt: json[YStrings.colLastRemoteUpdatedAt] as String?,
    );
  }

  /// Convert to Map (for DB/Firestore)
  Map<String, dynamic> toMap() {
    return {
      YStrings.colEntity: entity,
      YStrings.colLastLocalUpdatedAt: lastLocalUpdatedAt,
      YStrings.colLastRemoteUpdatedAt: lastRemoteUpdatedAt,
    };
  }

  /// Empty/default model
  factory SyncMetadataModel.empty() {
    return SyncMetadataModel(
      entity: '',
      lastLocalUpdatedAt: null,
      lastRemoteUpdatedAt: null,
    );
  }

  /// Create a copy with modifications
  SyncMetadataModel copyWith({
    String? entity,
    String? lastLocalUpdatedAt,
    String? lastRemoteUpdatedAt,
  }) {
    return SyncMetadataModel(
      entity: entity ?? this.entity,
      lastLocalUpdatedAt: lastLocalUpdatedAt ?? this.lastLocalUpdatedAt,
      lastRemoteUpdatedAt: lastRemoteUpdatedAt ?? this.lastRemoteUpdatedAt,
    );
  }

  /// Helpers
  bool get hasLocalChanges =>
      lastLocalUpdatedAt != null && lastRemoteUpdatedAt != null
      ? DateTime.tryParse(lastLocalUpdatedAt!)?.isAfter(
              DateTime.tryParse(lastRemoteUpdatedAt!) ?? DateTime(1970),
            ) ??
            false
      : false;

  bool get hasRemoteChanges =>
      lastRemoteUpdatedAt != null && lastLocalUpdatedAt != null
      ? DateTime.tryParse(lastRemoteUpdatedAt!)?.isAfter(
              DateTime.tryParse(lastLocalUpdatedAt!) ?? DateTime(1970),
            ) ??
            false
      : false;
}
