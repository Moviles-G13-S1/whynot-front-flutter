import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/domain/category.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_repository.dart';

class FirebaseWishlistRepository implements WishlistRepository {
  FirebaseWishlistRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Wishlist>> watchByOwner(String ownerId) => _firestore
      .collection('wishlists')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_fromDocument).toList());

  @override
  Future<List<Wishlist>> getByOwner(String ownerId) async {
    final snapshot = await _firestore
        .collection('wishlists')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.docs.map(_fromDocument).toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs
        .map(
          (document) => Category(
            id: document.id,
            name: document.data()['name'] as String? ?? document.id,
          ),
        )
        .toList();
  }

  @override
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
  }) async {
    final document = await _firestore.collection('wishlists').add({
      'ownerId': ownerId,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Wishlist _fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return Wishlist(
      id: document.id,
      ownerId: data['ownerId'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
