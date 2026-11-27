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
  late int calls;
  late ProductSearchResultCache cache;
  late List<Product> products;

  setUp(() {
    calls = 0;
    products = [item('1', 'AirPods'), item('2', 'iPhone', price: 800)];
    cache = ProductSearchResultCache(
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

  test('equal frequencies evict the oldest inserted entry', () async {
    final bounded = ProductSearchResultCache(
      maxEntries: 2,
      worker: (r) async {
        calls++;
        return r.products;
      },
    );
    // Both a and b have frequency 2; a was inserted first but accessed last.
    for (final term in ['a', 'b', 'b', 'a', 'c', 'b']) {
      await bounded.resolve(ownerId: 'u', request: request(products, term));
    }
    expect(calls, 3);
    await bounded.resolve(ownerId: 'u', request: request(products, 'a'));
    expect(calls, 4);
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

  test(
    'LFU retains frequent results even when a rarer query was accessed later',
    () async {
      final bounded = ProductSearchResultCache(
        maxEntries: 2,
        worker: (r) async {
          calls++;
          return r.products;
        },
      );
      // a: 3 accesses; b: 2 accesses and more recent. c must evict b, not a.
      for (final term in ['a', 'b', 'a', 'a', 'b', 'c', 'a']) {
        await bounded.resolve(ownerId: 'u', request: request(products, term));
      }
      expect(calls, 3);
      await bounded.resolve(ownerId: 'u', request: request(products, 'b'));
      expect(calls, 4);
    },
  );
}
