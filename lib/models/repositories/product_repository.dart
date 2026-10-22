import '../product.dart';

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

  /// Records a manual product-save attempt for BQ Type 2 analytics.
  ///
  /// success = true: the product was saved successfully.
  /// success = false: the backend failed to save the product.
  Future<void> recordSaveAttempt({
    required String ownerId,
    required bool success,
  });
}
