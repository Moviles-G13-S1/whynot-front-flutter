import 'package:whynot_mobile/app/app_dependencies.dart';
import 'package:whynot_mobile/features/admin/application/admin_access.dart';
import 'package:whynot_mobile/features/authentication/application/auth_controller.dart';
import 'package:whynot_mobile/features/authentication/domain/auth_user.dart';
import 'package:whynot_mobile/features/nearby/application/nearby_store_controller.dart';
import 'package:whynot_mobile/features/products/application/product_controller.dart';
import 'package:whynot_mobile/features/profile/application/profile_controller.dart';
import 'package:whynot_mobile/features/recommendations/application/recommendation_controller.dart';
import 'package:whynot_mobile/features/wishlists/application/wishlist_controller.dart';

import 'in_memory_location_repository.dart';
import 'in_memory_nearby_store_repository.dart';
import 'in_memory_recommendation_repository.dart';
import 'in_memory_repositories.dart';

/// Creates an isolated dependency graph for widget and application tests.
///
/// Firebase, Cloud Functions, and device location services are replaced by
/// in-memory implementations so tests do not depend on external services.
AppDependencies createTestDependencies({
  bool signedIn = false,
}) {
  final auth = InMemoryAuthRepository(
    user: signedIn
        ? const AuthUser(
            id: 'test-user',
            email: 'user@example.com',
          )
        : null,
  );

  final users = InMemoryUserRepository();
  final wishlists = InMemoryWishlistRepository();
  final products = InMemoryProductRepository();

  final recommendations = InMemoryRecommendationRepository();

  final location = InMemoryLocationRepository();
  final nearbyStores = InMemoryNearbyStoreRepository();

  final wishlistController = WishlistController(
    authRepository: auth,
    wishlistRepository: wishlists,
  );

  return AppDependencies(
    authController: AuthController(
      authRepository: auth,
      userRepository: users,
    ),
    profileController: ProfileController(
      authRepository: auth,
      userRepository: users,
    ),
    wishlistController: wishlistController,
    productController: ProductController(
      authRepository: auth,
      productRepository: products,
      wishlistController: wishlistController,
    ),
    adminAccessController: AdminAccessController(
      auth,
    ),
    recommendationController: RecommendationController(
      recommendationRepository: recommendations,
    ),
    nearbyStoreController: NearbyStoreController(
      locationRepository: location,
      nearbyStoreRepository: nearbyStores,
    ),
  );
}