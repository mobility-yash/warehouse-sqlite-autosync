enum OperationType { import, export }

enum OperationStatus { pending, synced }

class Operation {
  final String uuid;
  final String itemId;
  final String itemName;
  final OperationType type;
  final int quantity;
  final DateTime localPerformedAt;
  DateTime? serverSyncedAt;
  OperationStatus status;

  Operation({
    required this.uuid,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.localPerformedAt,
    this.serverSyncedAt,
    this.status = OperationStatus.pending,
  });

  factory Operation.fromMap(Map<String, dynamic> map) {
    return Operation(
      uuid: map['uuid'],
      itemId: map['itemId'],
      itemName: map['itemName'],
      type: map['type'] == "import"
          ? OperationType.import
          : OperationType.export,
      quantity: map['quantity'],
      localPerformedAt: DateTime.parse(map['localPerformedAt']),
      serverSyncedAt: map['serverSyncedAt'] != null
          ? DateTime.tryParse(map['serverSyncedAt'])
          : null,
      status: map['status'] == 'synced'
          ? OperationStatus.synced
          : OperationStatus.pending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uuid": uuid,
      "itemId": itemId,
      "itemName": itemName,
      "type": type.name,
      "quantity": quantity,
      "localPerformedAt": localPerformedAt.toIso8601String(),
      "serverSyncedAt": serverSyncedAt?.toIso8601String(),
      "status": status.name,
    };
  }
}

extension OperationFirestoreX on Operation {
  Map<String, dynamic> toFirestore() {
    return {
      "uuid": uuid,
      "itemId": itemId,
      "itemName": itemName,
      "type": type.name,
      "quantity": quantity,
      "performedAt": localPerformedAt.toIso8601String(),
      "serverSyncedAt": serverSyncedAt?.toIso8601String(),
      "status": status.name,
    };
  }
}
