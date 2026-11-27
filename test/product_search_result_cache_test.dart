import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/product_search_controller.dart';
import 'package:whynot_mobile/controllers/product_search_result_cache.dart';
import 'package:whynot_mobile/models/product.dart';

Product item(
  String id,
  String name, {
  double price = 100,
  String owner = 'u',
}) => Product(
  id: id,
  ownerId: owner,
  wishlistId: 'w',
  categoryId: 'technology',
  name: name,
  brand: 'Apple',
  price: price,
  imageUrl: '',
  productUrl: '',
  purchased: false,
);

ProductSearchRequest request(
  List<Product> products,
  String query, {
  double? maxPrice,
}) => (
  products: products,
  query: query,
  categoryId: null,
  minPrice: null,
  maxPrice: maxPrice,
);

void main() {
  late Duration time;
  late int calls;
  late ProductSearchResultCache cache;
  late List<Product> products;

  setUp(() {
    time = Duration.zero;
    calls = 0;
    products = [item('1', 'AirPods'), item('2', 'iPhone', price: 800)];
    cache = ProductSearchResultCache(
      elapsed: () => time,
      worker: (r) async {
        calls++;
        return const ProductSearchController().filter(
          r.products,
          query: r.query,
          categoryId: r.categoryId,
          minPrice: r.minPrice,
          maxPrice: r.maxPrice,
        );
      },
    );
  });

  test('repeated normalized query reuses completed results', () async {
    final a = await cache.resolve(
      ownerId: 'u',
      request: request(products, 'AirPods'),
    );
    await cache.resolve(ownerId: 'u', request: request(products, 'iPhone'));
    final b = await cache.resolve(
      ownerId: 'u',
      request: request(products, ' AIRPODS '),
    );
    expect(b.map((p) => p.id), ['1']);
    expect(identical(a, b), isTrue);
    expect(calls, 2);
  });

  test('expiry at 60 seconds is not extended by reads', () async {
    final r = request(products, 'Apple');
    await cache.resolve(ownerId: 'u', request: r);
    time = const Duration(seconds: 59);
    await cache.resolve(ownerId: 'u', request: r);
    expect(calls, 1);
    time = const Duration(seconds: 60);
    await cache.resolve(ownerId: 'u', request: r);
    expect(calls, 2);
  });

  test(
    'different price filters and empty results are cached independently',
    () async {
      final a = request(products, 'Apple', maxPrice: 200);
      final b = request(products, 'Apple', maxPrice: 10);
      expect((await cache.resolve(ownerId: 'u', request: a)).map((p) => p.id), [
        '1',
      ]);
      expect(await cache.resolve(ownerId: 'u', request: b), isEmpty);
      expect(await cache.resolve(ownerId: 'u', request: b), isEmpty);
      expect(calls, 2);
    },
  );

  test('new product snapshot invalidates old results', () async {
    await cache.resolve(ownerId: 'u', request: request(products, 'AirPods'));
    final updated = [item('1', 'AirPods', price: 999)];
    final results = await cache.resolve(
      ownerId: 'u',
      request: request(updated, 'AirPods'),
    );
    expect(results.single.price, 999);
    expect(calls, 2);
  });

  test(
    'account switch and explicit invalidation do not reuse results',
    () async {
      await cache.resolve(ownerId: 'u', request: request(products, 'Apple'));
      final other = [item('3', 'AirPods', owner: 'v')];
      expect(
        (await cache.resolve(
          ownerId: 'v',
          request: request(other, 'Apple'),
        )).single.ownerId,
        'v',
      );
      cache.invalidate();
      await cache.resolve(ownerId: 'v', request: request(other, 'Apple'));
      expect(calls, 3);
    },
  );

  test('old in-flight search cannot repopulate invalidated cache', () async {
    final old = Completer<List<Product>>();
    var executions = 0;
    final isolated = ProductSearchResultCache(
      worker: (r) async {
        executions++;
        if (executions == 1) return old.future;
        return r.products;
      },
    );
    final r = request(products, 'Apple');
    final pending = isolated.resolve(ownerId: 'u', request: r);
    isolated.invalidate();
    old.complete(products);
    await pending;
    await isolated.resolve(ownerId: 'u', request: r);
    expect(executions, 2);
  });

  test('bounded cache evicts oldest inserted entry', () async {
    final bounded = ProductSearchResultCache(
      maxEntries: 2,
      worker: (r) async {
        calls++;
        return r.products;
      },
    );
    for (final term in ['a', 'b', 'a', 'c', 'a']) {
      await bounded.resolve(ownerId: 'u', request: request(products, term));
    }
    expect(calls, 4);
  });
}
