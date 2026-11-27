import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/product_controller.dart';
import 'package:whynot_mobile/controllers/wishlist_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/repositories/auth_repository.dart';
import 'package:whynot_mobile/models/repositories/product_repository.dart';

class _Auth extends Fake implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(id: 'a', email: null);
}

class _Wishlists extends Fake implements WishlistController {}

class _Products extends Fake implements ProductRepository {
  _Products(this.events);
  final Stream<OwnerProducts> Function() events;
  @override
  Stream<OwnerProducts> watchOwnerProducts(String ownerId) => events();
}

const _item = Product(
  id: 'p',
  ownerId: 'a',
  wishlistId: 'w',
  categoryId: 'technology',
  name: 'AirPods',
  brand: 'Apple',
  price: 100,
  imageUrl: '',
  productUrl: '',
  purchased: false,
);

ProductController controller(Stream<OwnerProducts> Function() events) =>
    ProductController(
      authRepository: _Auth(),
      productRepository: _Products(events),
      wishlistController: _Wishlists(),
    );

void main() {
  test(
    'remote error preserves previously available search results as stale',
    () async {
      final result = await controller(() async* {
        yield const OwnerProducts(products: [_item]);
        throw StateError('offline');
      }).watchSearchProducts().toList();
      expect(result.length, 2);
      expect(result.first.fromCache, isFalse);
      expect(result.last.fromCache, isTrue);
      expect(result.last.products.single.id, 'p');
    },
  );

  test('failure without any snapshot remains an error', () async {
    final stream = controller(
      () => Stream<OwnerProducts>.error(StateError('offline')),
    ).watchSearchProducts();
    await expectLater(
      stream,
      emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
    );
  });

  test('cache-only data is followed by a server-confirmed result', () async {
    final result = await controller(() async* {
      yield const OwnerProducts(products: [], fromCache: true);
      yield const OwnerProducts(products: [_item]);
    }).watchSearchProducts().toList();
    expect(result.first.fromCache, isTrue);
    expect(result.last.fromCache, isFalse);
    expect(result.last.products.single.id, 'p');
  });
}
