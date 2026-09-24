import '../features/admin/application/admin_access.dart';
import '../features/admin/application/admin_metrics_controller.dart';
import '../features/admin/data/firebase_admin_metrics_repository.dart';
import '../features/admin/domain/admin_metrics_repository.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/authentication/data/firebase_auth_repository.dart';
import '../features/authentication/domain/auth_repository.dart';
import '../features/nearby/application/nearby_store_controller.dart';
import '../features/nearby/data/firebase_nearby_store_repository.dart';
import '../features/nearby/data/geolocator_location_repository.dart';
import '../features/nearby/domain/location_repository.dart';
import '../features/nearby/domain/nearby_store_repository.dart';
import '../features/products/application/product_controller.dart';
import '../features/products/data/firebase_product_repository.dart';
import '../features/products/domain/product_repository.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/data/firebase_user_repository.dart';
import '../features/profile/domain/user_repository.dart';
import '../features/recommendations/application/recommendation_controller.dart';
import '../features/recommendations/data/firebase_recommendation_repository.dart';
import '../features/recommendations/domain/recommendation_repository.dart';
import '../features/wishlists/application/wishlist_controller.dart';
import '../features/wishlists/data/firebase_wishlist_repository.dart';
import '../features/wishlists/domain/wishlist_repository.dart';
import '../shared/data/firebase_city_repository.dart';
import '../shared/domain/city_repository.dart';

/// Composition root for application dependencies.
///
/// Concrete repository implementations are created here and injected into
/// controllers. Presentation widgets access these controllers through
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
    required this.cityRepository,
    required this.recommendationController,
    required this.nearbyStoreController,
  });

  /// Creates the production/default dependency graph.
  ///
  /// In local development, Firebase SDK instances are redirected to the
  /// Emulator Suite during application startup in `main.dart`; repositories
  /// themselves remain environment-independent.
  factory AppDependencies.firebase() {
    final AuthRepository authRepository = FirebaseAuthRepository();
    final UserRepository userRepository = FirebaseUserRepository();
    final WishlistRepository wishlistRepository = FirebaseWishlistRepository();
    final ProductRepository productRepository = FirebaseProductRepository();
    final AdminMetricsRepository adminMetricsRepository =
        FirebaseAdminMetricsRepository();

    final RecommendationRepository recommendationRepository =
        FirebaseRecommendationRepository();

    final LocationRepository locationRepository =
        GeolocatorLocationRepository();

    final NearbyStoreRepository nearbyStoreRepository =
        FirebaseNearbyStoreRepository();

    final wishlistController = WishlistController(
      authRepository: authRepository,
      wishlistRepository: wishlistRepository,
    );

    return AppDependencies(
      authController: AuthController(
        authRepository: authRepository,
        userRepository: userRepository,
      ),
      profileController: ProfileController(
        authRepository: authRepository,
        userRepository: userRepository,
      ),
      wishlistController: wishlistController,
      productController: ProductController(
        authRepository: authRepository,
        productRepository: productRepository,
        wishlistController: wishlistController,
      ),
      adminAccessController: AdminAccessController(authRepository),
      adminMetricsController: AdminMetricsController(adminMetricsRepository),
      cityRepository: FirebaseCityRepository(),
      recommendationController: RecommendationController(
        recommendationRepository: recommendationRepository,
      ),
      nearbyStoreController: NearbyStoreController(
        locationRepository: locationRepository,
        nearbyStoreRepository: nearbyStoreRepository,
      ),
    );
  }

  final AuthController authController;
  final ProfileController profileController;
  final WishlistController wishlistController;
  final ProductController productController;
  final AdminAccessController adminAccessController;
  final AdminMetricsController adminMetricsController;
  final CityRepository cityRepository;

  /// Controller for the demographic Smart Recommendation feature.
  final RecommendationController recommendationController;

  /// Controller for the location-based Context-Aware feature.
  final NearbyStoreController nearbyStoreController;
}
