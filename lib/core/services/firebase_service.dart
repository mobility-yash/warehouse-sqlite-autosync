import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:warehouse_data_autosync/data/models/item.dart';
import 'package:warehouse_data_autosync/data/models/operation.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;

  // fetch items from Firestore
  Future<List<Item>> fetchItems() async {
    final snapshot = await _firestore.collection('items').get();
    return snapshot.docs
        .map((doc) => Item.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // update item quantity
  Future<void> updateItem(Item item) async {
    await _firestore
        .collection('items')
        .doc(item.id)
        .update(item.toFirestore());
  }

  // upload operation
  Future<void> addOperation(Operation op) async {
    await _firestore
        .collection('operations')
        .doc(op.uuid)
        .set(op.toFirestore());
  }

  Future<Item> getItemById(String id) async {
    final doc = await _firestore.collection("items").doc(id).get();
    final data = doc.data()!;
    return Item.fromFirestore(data, doc.id);
  }
}
