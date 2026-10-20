import 'package:whynot_mobile/app/app_dependencies.dart';
import 'package:whynot_mobile/controllers/admin_access_controller.dart';
import 'package:whynot_mobile/controllers/admin_metrics_controller.dart';
import 'package:whynot_mobile/controllers/auth_controller.dart';
import 'package:whynot_mobile/controllers/city_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/controllers/nearby_store_controller.dart';
import 'package:whynot_mobile/controllers/product_controller.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/controllers/profile_controller.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/controllers/speech_controller.dart';
import 'package:whynot_mobile/controllers/wishlist_controller.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/repositories/city_repository.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';
import 'package:whynot_mobile/models/wishlist.dart';

import 'in_memory_admin_metrics_repository.dart';
import 'in_memory_location_repository.dart';
import 'in_memory_nearby_store_repository.dart';
import 'in_memory_recommendation_repository.dart';
import 'in_memory_repositories.dart';
import 'in_memory_speech_recognition_repository.dart';

/// Creates an isolated dependency graph for widget and application tests.
///
/// Firebase, Cloud Functions, device location, and speech recognition services
/// are replaced by in-memory implementations so tests do not depend on
/// external services.
AppDependencies createTestDependencies({
  bool signedIn = false,
  List<Product> products = const [],
  List<UserProfile> profiles = const [],
  List<Category> categories = const [],
  int recommendedProductSaves = 0,
  CityRepository? cityRepository,
  RecommendationRepository? recommendationRepository,
  List<Wishlist> wishlists = const [],
}) {
  final auth = InMemoryAuthRepository(
    user: signedIn
        ? const AuthUser(id: 'test-user', email: 'user@example.com')
        : null,
  );

  final users = InMemoryUserRepository();
  users.profiles.addAll({for (final profile in profiles) profile.id: profile});

  final wishlistRepository = InMemoryWishlistRepository(
    categories: categories,
    wishlists: wishlists,
  );
  final productRepository = InMemoryProductRepository(products: products);

  final recommendations =
      recommendationRepository ?? InMemoryRecommendationRepository();

  final location = InMemoryLocationRepository();
  final nearbyStores = InMemoryNearbyStoreRepository();

  final speech = InMemorySpeechRecognitionRepository();

  final wishlistController = WishlistController(
    authRepository: auth,
    wishlistRepository: wishlistRepository,
  );

  return AppDependencies(
    authController: AuthController(authRepository: auth, userRepository: users),
    profileController: ProfileController(
      authRepository: auth,
      userRepository: users,
    ),
    wishlistController: wishlistController,
    productController: ProductController(
      authRepository: auth,
      productRepository: productRepository,
      wishlistController: wishlistController,
    ),
    adminAccessController: AdminAccessController(auth),
    adminMetricsController: AdminMetricsController(
      InMemoryAdminMetricsRepository(total: recommendedProductSaves),
    ),
    cityController: CityController(
      cityRepository: cityRepository ?? InMemoryCityRepository(),
    ),
    recommendationController: RecommendationController(
      recommendationRepository: recommendations,
    ),
    nearbyStoreController: NearbyStoreController(
      locationRepository: location,
      nearbyStoreRepository: nearbyStores,
    ),
    speechController: SpeechController(speechRecognitionRepository: speech),
  );
}
