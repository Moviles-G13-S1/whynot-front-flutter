import '../controllers/admin_access_controller.dart';
import '../controllers/admin_metrics_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/city_controller.dart';
import '../controllers/connectivity_status.dart';
import '../controllers/nearby_store_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/recommendation_controller.dart';
import '../controllers/wishlist_controller.dart';

import '../models/repositories/admin_metrics_repository.dart';
import '../models/repositories/auth_repository.dart';
import '../models/repositories/location_repository.dart';
import '../models/repositories/nearby_store_repository.dart';
import '../models/repositories/product_repository.dart';
import '../models/repositories/recommendation_repository.dart';
import '../models/repositories/user_repository.dart';
import '../models/repositories/wishlist_repository.dart';

import '../infrastructure/repositories/firebase_admin_metrics_repository.dart';
import '../infrastructure/repositories/firebase_auth_repository.dart';
import '../infrastructure/repositories/firebase_city_repository.dart';
import '../infrastructure/repositories/firebase_nearby_store_repository.dart';
import '../infrastructure/repositories/firebase_product_repository.dart';
import '../infrastructure/repositories/firebase_recommendation_repository.dart';
import '../infrastructure/repositories/firebase_user_repository.dart';
import '../infrastructure/repositories/firebase_profile_photo_repository.dart';
import '../infrastructure/repositories/firebase_wishlist_repository.dart';
import '../infrastructure/repositories/geolocator_location_repository.dart';

/// Composition root for application dependencies.
///
/// Concrete repository implementations are created here and injected into
/// controllers. View widgets access these controllers through
/// [DependenciesScope] instead of constructing Firebase or platform services
/// directly.
class AppDependencies {
  AppDependencies({
    required this.authController,
    required this.profileController,
    required this.wishlistController,
    required this.productController,
    required this.adminAccessController,
    required this.adminMetricsController,
    required this.cityController,
    required this.recommendationController,
    required this.nearbyStoreController,
  });

  /// Creates the production/default dependency graph.
  ///
  /// In local development, Firebase SDK instances are redirected to the
  /// Emulator Suite during application startup in `main.dart`; repositories
  /// themselves remain environment-independent.
  // Santiago Casasbuenas: Inject the profile photo repository in production.
  factory AppDependencies.firebase() {
    final AuthRepository authRepository = FirebaseAuthRepository();
    final UserRepository userRepository = FirebaseUserRepository();
    final WishlistRepository wishlistRepository = FirebaseWishlistRepository();
    final ProductRepository productRepository = FirebaseProductRepository();
    final AdminMetricsRepository adminMetricsRepository =
        FirebaseAdminMetricsRepository();

    final RecommendationRepository recommendationRepository =
        FirebaseRecommendationRepository();
    final connectivity = ConnectivityStatus();
    // Santiago Casasbuenas: One cache-owning controller is shared by both
    // recommendation views and by mutation/auth invalidation callbacks.
    final recommendationController = RecommendationController(
      recommendationRepository: recommendationRepository,
      authRepository: authRepository,
      connectivity: connectivity,
    );

    final LocationRepository locationRepository =
        GeolocatorLocationRepository();

    final NearbyStoreRepository nearbyStoreRepository =
        FirebaseNearbyStoreRepository();

    final wishlistController = WishlistController(
      authRepository: authRepository,
      wishlistRepository: wishlistRepository,
      onRecommendationInputsChanged: recommendationController.invalidateForUser,
    );

    return AppDependencies(
      authController: AuthController(
        authRepository: authRepository,
        userRepository: userRepository,
        onAuthChanged: recommendationController.clearCache,
      ),
      profileController: ProfileController(
        authRepository: authRepository,
        userRepository: userRepository,
        photoRepository: FirebaseProfilePhotoRepository(),
        onRecommendationInputsChanged:
            recommendationController.invalidateForUser,
      ),
      wishlistController: wishlistController,
      productController: ProductController(
        authRepository: authRepository,
        productRepository: productRepository,
        wishlistController: wishlistController,
        onRecommendationInputsChanged:
            recommendationController.invalidateForUser,
      ),
      adminAccessController: AdminAccessController(authRepository),
      adminMetricsController: AdminMetricsController(adminMetricsRepository),
      cityController: CityController(cityRepository: FirebaseCityRepository()),
      recommendationController: recommendationController,
      nearbyStoreController: NearbyStoreController(
        locationRepository: locationRepository,
        nearbyStoreRepository: nearbyStoreRepository,
        authRepository: authRepository,
        connectivity: connectivity,
      ),
    );
  }

  final AuthController authController;
  final ProfileController profileController;
  final WishlistController wishlistController;
  final ProductController productController;
  final AdminAccessController adminAccessController;
  final AdminMetricsController adminMetricsController;
  final CityController cityController;

  /// Controller for the demographic Smart Recommendation feature.
  final RecommendationController recommendationController;

  /// Controller for the location-based Context-Aware feature.
  final NearbyStoreController nearbyStoreController;
}
