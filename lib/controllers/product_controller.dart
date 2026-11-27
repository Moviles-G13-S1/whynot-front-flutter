import 'dart:async';

import '../models/repositories/auth_repository.dart';
import '../infrastructure/repositories/sqlite_search_product_store.dart';
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
    this.searchProductStore,
  }) : _authRepository = authRepository,
       _productRepository = productRepository,
       _wishlistController = wishlistController;

  final AuthRepository _authRepository;
  final ProductRepository _productRepository;
  final WishlistController _wishlistController;
  final SqliteSearchProductStore? searchProductStore;
  final FutureOr<void> Function(String userId)? onRecommendationInputsChanged;

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

  /// Santiago Casasbuenas: Current user's products with their cache state.
  Stream<OwnerProducts> watchCurrentOwnerProducts() {
    final ownerId = currentUserId;
    return ownerId == null
        ? Stream.value(const OwnerProducts(products: []))
        : _productRepository.watchOwnerProducts(ownerId);
  }

  /// Search has its own durable snapshot without changing other product views.
  Stream<OwnerProducts> watchSearchProducts() async* {
    final ownerId = currentUserId;
    if (ownerId == null) return;
    final store = searchProductStore;
    List<Product>? saved;
    if (store != null) {
      try {
        saved = await store.load(ownerId);
      } catch (_) {
        // A local storage failure must not prevent online search.
      }
    }
    if (currentUserId != ownerId) return;
    if (saved != null) {
      yield OwnerProducts(products: saved, fromCache: true);
    }
    await for (final data in _productRepository.watchOwnerProducts(ownerId)) {
      if (currentUserId != ownerId) return;
      if (data.fromCache && !data.hasPendingWrites && saved != null) {
        // A Firestore cache-only snapshot may be incomplete. Do not replace
        // a complete server-confirmed local collection with it.
        yield OwnerProducts(products: saved, fromCache: true);
        continue;
      }
      if (!data.fromCache && !data.hasPendingWrites) {
        saved = data.products;
        if (store != null) {
          try {
            await store.save(ownerId, saved);
          } catch (_) {
            // The current remote result remains usable even if disk is full.
          }
        }
      }
      if (currentUserId != ownerId) return;
      yield data;
    }
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
    unawaited(_recordSaveAttempt(ownerId: ownerId, success: true));
    await onRecommendationInputsChanged?.call(ownerId);
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
    if (id != null) await onRecommendationInputsChanged?.call(id);
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
    if (id != null) await onRecommendationInputsChanged?.call(id);
  }

  Future<void> delete(String productId) async {
    final id = currentUserId;
    await _productRepository.delete(productId);
    if (id != null) await onRecommendationInputsChanged?.call(id);
  }
}
