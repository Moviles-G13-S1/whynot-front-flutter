import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/product.dart';
import '../domain/product_repository.dart';

class FirebaseProductRepository implements ProductRepository {
  FirebaseProductRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Product>> watchByWishlist(String wishlistId) => _firestore
      .collection('products')
      .where('wishlistId', isEqualTo: wishlistId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_fromQueryDocument).toList());

  @override
  Stream<List<Product>> watchByOwner(String ownerId) => _firestore
      .collection('products')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_fromQueryDocument).toList());

  @override
  Stream<Product?> watch(String productId) => _firestore
      .collection('products')
      .doc(productId)
      .snapshots()
      .map(_fromDocument);

  @override
  Future<Product?> get(String productId) async {
    final document = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    return _fromDocument(document);
  }

  @override
  Future<void> create({required String ownerId, required ProductDraft draft}) =>
      _firestore.collection('products').add({
        'ownerId': ownerId,
        ..._draftData(draft),
        'purchased': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> update(String productId, ProductDraft draft) =>
      _firestore.collection('products').doc(productId).update({
        ..._draftData(draft),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> setPurchased(String productId, {required bool purchased}) =>
      _firestore.collection('products').doc(productId).update({
        'purchased': purchased,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> delete(String productId) =>
      _firestore.collection('products').doc(productId).delete();

  Map<String, Object> _draftData(ProductDraft draft) => {
    'wishlistId': draft.wishlistId,
    'categoryId': draft.categoryId,
    'name': draft.name,
    'brand': draft.brand,
    'price': draft.price,
    'imageUrl': draft.imageUrl,
    'productUrl': draft.productUrl,
  };

  Product _fromQueryDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => _product(document.id, document.data());

  Product? _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return data == null ? null : _product(document.id, data);
  }

  Product _product(String id, Map<String, dynamic> data) => Product(
    id: id,
    ownerId: data['ownerId'] as String? ?? '',
    wishlistId: data['wishlistId'] as String? ?? '',
    categoryId: data['categoryId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    brand: data['brand'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    imageUrl: data['imageUrl'] as String? ?? '',
    productUrl: data['productUrl'] as String? ?? '',
    purchased: data['purchased'] as bool? ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
  );
}
