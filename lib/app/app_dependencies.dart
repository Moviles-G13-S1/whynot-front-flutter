import '../controllers/admin_access_controller.dart';
import '../controllers/admin_metrics_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/city_controller.dart';
import '../controllers/connectivity_status.dart';
import '../controllers/nearby_store_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/profile_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/repositories/profile_photo_cache_store.dart';
import '../controllers/profile_photo_cache.dart';
import '../controllers/application_error_reporter.dart';
import '../infrastructure/repositories/firebase_application_error_sink.dart';
import '../infrastructure/repositories/sqlite_application_error_queue.dart';
import '../infrastructure/repositories/profile_photo_cache_stores.dart';
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
import '../infrastructure/repositories/sqlite_product_draft_store.dart';

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
    SqliteProductDraftStore? productDraftStore,
    BaseCacheManager? Function()? photoCacheManager,
    this.errorReporter,
  }) : productDraftStore = productDraftStore ?? SqliteProductDraftStore(),
       _photoCacheManager = photoCacheManager;

  final BaseCacheManager? Function()? _photoCacheManager;
  final ApplicationErrorReporter? errorReporter;
  BaseCacheManager? get photoCacheManager => _photoCacheManager?.call();

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
    final errorReporter = ApplicationErrorReporter(
      queue: SqliteApplicationErrorQueue(),
      sink: FirebaseApplicationErrorSink(),
      currentUserId: () => authRepository.currentUser?.id,
      connectivity: connectivity,
    );
    final photoRepository = FirebaseProfilePhotoRepository();
    final ProfilePhotoCacheStore photoStore = kIsWeb
        ? SqliteProfilePhotoCacheStore()
        : ManagedProfilePhotoCacheStore();
    final photoCache = ProfilePhotoCache(
      store: photoStore,
      download: photoRepository.downloadBytes,
      currentUserId: () => authRepository.currentUser?.id,
    );
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
      errorReporter: errorReporter,
      photoCacheManager: () {
        final id = authRepository.currentUser?.id;
        return id != null && photoStore is ManagedProfilePhotoCacheStore
            ? photoStore.managerFor(id)
            : null;
      },
      authController: AuthController(
        authRepository: authRepository,
        userRepository: userRepository,
        onAuthChanged: recommendationController.clearCache,
        connectivity: connectivity,
        onSessionEnded: photoCache.clear,
        errorReporter: errorReporter,
      ),
      profileController: ProfileController(
        authRepository: authRepository,
        userRepository: userRepository,
        photoRepository: photoRepository,
        photoCache: photoCache,
        errorReporter: errorReporter,
        connectivity: connectivity,
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

  /// Shared transport status for auth, Home, Profile and smart features.
  ConnectivityStatus get connectivity => recommendationController.connectivity;

  /// Controller for the demographic Smart Recommendation feature.
  final RecommendationController recommendationController;

  /// Controller for the location-based Context-Aware feature.
  final NearbyStoreController nearbyStoreController;

  /// Shared local SQLite storage for unfinished product forms.
  ///
  /// A single instance is reused across product form visits,
  /// keeping database connections under control.
  final SqliteProductDraftStore productDraftStore;
}
