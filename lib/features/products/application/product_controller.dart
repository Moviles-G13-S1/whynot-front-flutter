import '../../authentication/domain/auth_repository.dart';
import '../../wishlists/application/wishlist_controller.dart';
import '../../wishlists/domain/wishlist.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class ProductController {
  const ProductController({
    required AuthRepository authRepository,
    required ProductRepository productRepository,
    required WishlistController wishlistController,
  }) : _authRepository = authRepository,
       _productRepository = productRepository,
       _wishlistController = wishlistController;

  final AuthRepository _authRepository;
  final ProductRepository _productRepository;
  final WishlistController _wishlistController;

  String? get currentUserId => _authRepository.currentUser?.id;
  Stream<List<Product>> watchAllProducts() => _productRepository.watchAll();
  Stream<List<Product>> watchByWishlist(String wishlistId) =>
      _productRepository.watchByWishlist(wishlistId);
  Stream<List<Product>> watchCurrentProducts() {
    final ownerId = currentUserId;
    return ownerId == null
        ? Stream.value(const [])
        : _productRepository.watchByOwner(ownerId);
  }

  Stream<Product?> watch(String productId) =>
      _productRepository.watch(productId);
  Future<Product?> get(String productId) => _productRepository.get(productId);
  Future<List<WishlistSummary>> getCurrentWishlists() =>
      _wishlistController.getCurrentSummaries();

  Future<void> create(ProductDraft draft) {
    final ownerId = currentUserId;
    if (ownerId == null) throw StateError('No user logged in.');
    return _productRepository.create(ownerId: ownerId, draft: draft);
  }

  Future<void> update(String productId, ProductDraft draft) =>
      _productRepository.update(productId, draft);
  Future<void> markPurchased(String productId) =>
      _productRepository.markPurchased(productId);
  Future<void> delete(String productId) => _productRepository.delete(productId);
}
