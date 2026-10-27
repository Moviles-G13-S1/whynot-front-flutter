import 'dart:async';

import '../models/repositories/auth_repository.dart';
import 'wishlist_controller.dart';
import '../models/wishlist.dart';
import '../models/product.dart';
import '../models/input_policy.dart';
import '../models/repositories/product_repository.dart';

class ProductController {
  const ProductController({
    required AuthRepository authRepository,
    required ProductRepository productRepository,
    required WishlistController wishlistController,
    this.onRecommendationInputsChanged,
  }) : _authRepository = authRepository,
       _productRepository = productRepository,
       _wishlistController = wishlistController;

  final AuthRepository _authRepository;
  final ProductRepository _productRepository;
  final WishlistController _wishlistController;
  final void Function(String userId)? onRecommendationInputsChanged;

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

  /// Creates a manual product and records the save attempt for BQ Type 2.
  Future<void> create(ProductDraft draft) async {
    final ownerId = currentUserId;

    if (ownerId == null) {
      throw StateError('No user logged in.');
    }

    _validateDraft(draft);

    try {
      await _productRepository.create(ownerId: ownerId, draft: draft);
    } catch (_) {
      // The product could not be saved.
      unawaited(_recordSaveAttempt(ownerId: ownerId, success: false));

      // Preserve the original error for the UI.
      rethrow;
    }

    // The product was successfully saved.
    // Santiago Casasbuenas: Product changes can change the recommended pick.
    onRecommendationInputsChanged?.call(ownerId);
    unawaited(_recordSaveAttempt(ownerId: ownerId, success: true));
  }

  /// Analytics must never prevent a product from being saved.
  Future<void> _recordSaveAttempt({
    required String ownerId,
    required bool success,
  }) async {
    try {
      await _productRepository.recordSaveAttempt(
        ownerId: ownerId,
        success: success,
      );
    } catch (_) {
      // Ignore analytics errors without affecting the user.
    }
  }

  Future<void> update(String productId, ProductDraft draft) async {
    _validateDraft(draft);
    final id = currentUserId;
    await _productRepository.update(productId, draft);
    if (id != null) onRecommendationInputsChanged?.call(id);
  }

  void _validateDraft(ProductDraft draft) {
    InputPolicy.noEmoji(draft.name, 'Product name');
    InputPolicy.noEmoji(draft.brand, 'Brand');
    InputPolicy.optionalWebUrl(draft.imageUrl, 'Picture link');
    InputPolicy.optionalWebUrl(draft.productUrl, 'Product link');
    if (draft.name.trim().isEmpty ||
        draft.brand.trim().isEmpty ||
        !draft.price.isFinite ||
        draft.price < 0) {
      throw const InputPolicyException('Enter a name, brand, and valid price.');
    }
  }

  Future<void> markPurchased(String productId) async {
    final id = currentUserId;
    await _productRepository.markPurchased(productId);
    if (id != null) onRecommendationInputsChanged?.call(id);
  }

  Future<void> delete(String productId) async {
    final id = currentUserId;
    await _productRepository.delete(productId);
    if (id != null) onRecommendationInputsChanged?.call(id);
  }
}
