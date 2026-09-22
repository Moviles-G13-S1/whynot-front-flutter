import '../features/admin/application/admin_access.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/authentication/data/firebase_auth_repository.dart';
import '../features/authentication/domain/auth_repository.dart';
import '../features/products/application/product_controller.dart';
import '../features/products/data/firebase_product_repository.dart';
import '../features/products/domain/product_repository.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/data/firebase_user_repository.dart';
import '../features/profile/domain/user_repository.dart';
import '../features/wishlists/application/wishlist_controller.dart';
import '../features/wishlists/data/firebase_wishlist_repository.dart';
import '../features/wishlists/domain/wishlist_repository.dart';

class AppDependencies {
  AppDependencies({
    required this.authController,
    required this.profileController,
    required this.wishlistController,
    required this.productController,
    required this.adminAccessController,
  });

  factory AppDependencies.firebase() {
    final AuthRepository authRepository = FirebaseAuthRepository();
    final UserRepository userRepository = FirebaseUserRepository();
    final WishlistRepository wishlistRepository = FirebaseWishlistRepository();
    final ProductRepository productRepository = FirebaseProductRepository();
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
    );
  }

  final AuthController authController;
  final ProfileController profileController;
  final WishlistController wishlistController;
  final ProductController productController;
  final AdminAccessController adminAccessController;
}
