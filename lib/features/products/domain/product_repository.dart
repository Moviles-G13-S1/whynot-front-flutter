import 'product.dart';

abstract interface class ProductRepository {
  Stream<List<Product>> watchAll();
  Stream<List<Product>> watchByWishlist(String wishlistId);
  Stream<List<Product>> watchByOwner(String ownerId);
  Stream<Product?> watch(String productId);
  Future<Product?> get(String productId);
  Future<void> create({required String ownerId, required ProductDraft draft});
  Future<void> update(String productId, ProductDraft draft);
  Future<void> markPurchased(String productId);
  Future<void> delete(String productId);
}
