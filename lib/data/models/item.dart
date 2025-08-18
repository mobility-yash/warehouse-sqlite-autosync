class Item {
  final String id;
  final String name;
  int quantity;
  DateTime lastFirebaseModified;
  DateTime lastLocalUpdate;

  Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.lastFirebaseModified,
    required this.lastLocalUpdate,
  });

  factory Item.fromFirestore(Map<String, dynamic> data, String docId) {
    return Item(
      id: docId,
      name: data['name'],
      quantity: data['quantity'],
      lastFirebaseModified: DateTime.parse(data['lastFirebaseModified']),
      lastLocalUpdate: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'quantity': quantity,
    'lastFirebaseModified': lastFirebaseModified.toIso8601String(),
  };
}

extension ItemFirestoreX on Item {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'quantity': quantity,
      'lastFirebaseModified': lastFirebaseModified.toIso8601String(),
    };
  }
}
