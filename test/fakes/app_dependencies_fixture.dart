import 'package:whynot_mobile/app/app_dependencies.dart';
import 'package:whynot_mobile/features/admin/application/admin_access.dart';
import 'package:whynot_mobile/features/authentication/application/auth_controller.dart';
import 'package:whynot_mobile/features/authentication/domain/auth_user.dart';
import 'package:whynot_mobile/features/products/application/product_controller.dart';
import 'package:whynot_mobile/features/profile/application/profile_controller.dart';
import 'package:whynot_mobile/features/wishlists/application/wishlist_controller.dart';

import 'in_memory_repositories.dart';

AppDependencies createTestDependencies({bool signedIn = false}) {
  final auth = InMemoryAuthRepository(
    user: signedIn
        ? const AuthUser(id: 'test-user', email: 'user@example.com')
        : null,
  );
  final users = InMemoryUserRepository();
  final wishlists = InMemoryWishlistRepository();
  final products = InMemoryProductRepository();
  final wishlistController = WishlistController(
    authRepository: auth,
    wishlistRepository: wishlists,
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
      productRepository: products,
      wishlistController: wishlistController,
    ),
    adminAccessController: AdminAccessController(auth),
  );
}
