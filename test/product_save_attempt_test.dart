import 'package:flutter_test/flutter_test.dart';

import 'package:whynot_mobile/controllers/product_controller.dart';
import 'package:whynot_mobile/controllers/wishlist_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/product.dart';

import 'fakes/in_memory_repositories.dart';

const productDraft = ProductDraft(
  wishlistId: 'wishlist-1',
  categoryId: 'technology',
  name: 'AirPods Pro',
  brand: 'Apple',
  price: 249,
  imageUrl: '',
  productUrl: '',
);

ProductController createController(
  InMemoryAuthRepository auth,
  InMemoryProductRepository products,
) {
  return ProductController(
    authRepository: auth,
    productRepository: products,
    wishlistController: WishlistController(
      authRepository: auth,
      wishlistRepository: InMemoryWishlistRepository(),
    ),
  );
}

class FailingProductRepository extends InMemoryProductRepository {
  @override
  Future<void> create({
    required String ownerId,
    required ProductDraft draft,
  }) async {
    throw StateError('Firebase save failed');
  }
}

class FailingAnalyticsRepository extends InMemoryProductRepository {
  @override
  Future<void> recordSaveAttempt({
    required String ownerId,
    required bool success,
  }) async {
    throw StateError('Analytics failed');
  }
}

void main() {
  late InMemoryAuthRepository auth;

  setUp(() {
    auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'test-user', email: 'test@example.com'),
    );
  });

  test('BQ Type 2 records a successful product save', () async {
    final products = InMemoryProductRepository();
    final controller = createController(auth, products);

    await controller.create(productDraft);

    // Allow the asynchronous analytics operation to finish.
    await Future<void>.delayed(Duration.zero);

    final savedProducts = await controller.watchCurrentProducts().first;

    expect(savedProducts.length, 1);
    expect(savedProducts.single.name, 'AirPods Pro');

    expect(products.saveAttempts.length, 1);
    expect(products.saveAttempts.single.ownerId, 'test-user');
    expect(products.saveAttempts.single.success, isTrue);
  });

  test('BQ Type 2 records a failed product save', () async {
    final products = FailingProductRepository();
    final controller = createController(auth, products);

    await expectLater(controller.create(productDraft), throwsStateError);

    await Future<void>.delayed(Duration.zero);

    final savedProducts = await controller.watchCurrentProducts().first;

    expect(savedProducts, isEmpty);
    expect(products.saveAttempts.length, 1);
    expect(products.saveAttempts.single.success, isFalse);
  });

  test('Analytics failure does not prevent saving', () async {
    final products = FailingAnalyticsRepository();
    final controller = createController(auth, products);

    await controller.create(productDraft);

    await Future<void>.delayed(Duration.zero);

    final savedProducts = await controller.watchCurrentProducts().first;

    expect(savedProducts.length, 1);
    expect(savedProducts.single.name, 'AirPods Pro');
  });
}
