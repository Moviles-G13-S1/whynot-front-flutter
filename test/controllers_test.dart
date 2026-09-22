import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/features/authentication/application/auth_controller.dart';
import 'package:whynot_mobile/features/authentication/domain/auth_user.dart';
import 'package:whynot_mobile/features/products/application/product_controller.dart';
import 'package:whynot_mobile/features/products/domain/product.dart';
import 'package:whynot_mobile/features/wishlists/application/wishlist_controller.dart';
import 'package:whynot_mobile/shared/domain/category.dart';

import 'fakes/in_memory_repositories.dart';

void main() {
  test(
    'account creation persists a typed profile through repositories',
    () async {
      final auth = InMemoryAuthRepository();
      final users = InMemoryUserRepository();
      final controller = AuthController(
        authRepository: auth,
        userRepository: users,
      );

      await controller.createAccount(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'password123',
        gender: 'Female',
        age: 28,
        preferredCategoryId: 'technology',
      );

      final profile = users.profiles['test-user'];
      expect(profile?.name, 'Ada Lovelace');
      expect(profile?.preferredCategoryId, 'technology');
    },
  );

  test('wishlist controller excludes categories already in use', () async {
    final auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'owner', email: 'owner@example.com'),
    );
    final repository = InMemoryWishlistRepository(
      categories: const [
        Category(id: 'fashion', name: 'Fashion'),
        Category(id: 'technology', name: 'Technology'),
      ],
      wishlists: const [],
    );
    final controller = WishlistController(
      authRepository: auth,
      wishlistRepository: repository,
    );
    await controller.create(categoryId: 'fashion', imageUrl: '');

    final available = await controller.getAvailableCategories();
    expect(available.single.key, 'technology');
    expect(available.single.value, 'Technology');
  });

  test(
    'product controller creates products with repository-owned identity',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'owner', email: 'owner@example.com'),
      );
      final wishlistController = WishlistController(
        authRepository: auth,
        wishlistRepository: InMemoryWishlistRepository(),
      );
      final products = InMemoryProductRepository();
      final controller = ProductController(
        authRepository: auth,
        productRepository: products,
        wishlistController: wishlistController,
      );

      await controller.create(
        const ProductDraft(
          wishlistId: 'wishlist-1',
          categoryId: 'technology',
          name: 'Headphones',
          brand: 'WhyNot',
          price: 99,
          imageUrl: '',
          productUrl: '',
        ),
      );

      final result = await controller.watchCurrentProducts().first;
      expect(result.single.ownerId, 'owner');
      expect(result.single.purchased, isFalse);
    },
  );
}
