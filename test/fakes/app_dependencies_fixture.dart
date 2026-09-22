import 'package:whynot_mobile/app/app_dependencies.dart';
import 'package:whynot_mobile/features/admin/application/admin_access.dart';
import 'package:whynot_mobile/features/authentication/application/auth_controller.dart';
import 'package:whynot_mobile/features/authentication/domain/auth_user.dart';
import 'package:whynot_mobile/features/products/application/product_controller.dart';
import 'package:whynot_mobile/features/products/domain/product.dart';
import 'package:whynot_mobile/features/profile/application/profile_controller.dart';
import 'package:whynot_mobile/features/profile/domain/user_profile.dart';
import 'package:whynot_mobile/features/wishlists/application/wishlist_controller.dart';
import 'package:whynot_mobile/shared/domain/category.dart';

import 'in_memory_repositories.dart';

AppDependencies createTestDependencies({
  bool signedIn = false,
  List<Product> products = const [],
  List<UserProfile> profiles = const [],
  List<Category> categories = const [],
}) {
  final auth = InMemoryAuthRepository(
    user: signedIn
        ? const AuthUser(id: 'test-user', email: 'user@example.com')
        : null,
  );
  final users = InMemoryUserRepository();
  users.profiles.addAll({for (final profile in profiles) profile.id: profile});
  final wishlists = InMemoryWishlistRepository(categories: categories);
  final productRepository = InMemoryProductRepository(products: products);
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
      productRepository: productRepository,
      wishlistController: wishlistController,
    ),
    adminAccessController: AdminAccessController(auth),
    cityRepository: InMemoryCityRepository(),
  );
}
