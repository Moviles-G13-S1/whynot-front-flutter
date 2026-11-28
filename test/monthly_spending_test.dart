import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/monthly_spending_cache.dart';
import 'package:whynot_mobile/controllers/monthly_spending_controller.dart';
import 'package:whynot_mobile/models/monthly_spending.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/repositories/spending_store.dart';

Product purchase(
  String id, {
  double price = 10,
  String category = 'fashion',
  DateTime? date,
  String owner = 'u',
  bool purchased = true,
}) => Product(
  id: id,
  ownerId: owner,
  wishlistId: 'w',
  categoryId: category,
  name: 'Product $id',
  brand: 'Brand',
  price: price,
  imageUrl: '',
  productUrl: '',
  purchased: purchased,
  purchasedAt: date,
);

class MemorySpendingStore implements SpendingStore {
  final values = <String, SpendingSnapshot>{};
  @override
  Future<SpendingSnapshot?> load(String userId) async => values[userId];
  @override
  Future<void> save(String userId, SpendingSnapshot snapshot) async {
    values[userId] = snapshot;
  }

  @override
  Future<void> clear(String userId) async {
    values.remove(userId);
  }
}

MonthlySpendingCache immediateCache({int capacity = 6}) => MonthlySpendingCache(
  capacity: capacity,
  worker: (request) async => calculateMonthlySpending(request),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Bogota month boundaries, zero-price products, cents and deterministic grouping',
    () {
      final products = [
        purchase('a', price: 0.1, date: DateTime.utc(2026, 12, 1, 4, 59)),
        purchase('b', price: 0.2, date: DateTime.utc(2026, 11, 12)),
        purchase(
          'free',
          price: 0,
          category: 'gifts',
          date: DateTime.utc(2026, 11, 14),
        ),
        purchase('december', price: 500, date: DateTime.utc(2026, 12, 1, 5)),
        purchase('undated', price: 999),
      ].map((p) => SpendingPurchase.fromProduct(p)!).toList();
      final result = calculateMonthlySpending((
        month: '2026-11',
        purchases: products,
      ));
      expect(result.totalCents, 30);
      expect(result.count, 3);
      expect(result.categories.map((c) => c.id), ['fashion', 'gifts']);
      expect(result.categories.first.products.map((p) => p.id), ['a', 'b']);
      expect(
        SpendingPurchase.fromProduct(purchase('bad', price: double.nan)),
        isNull,
      );
      expect(SpendingPurchase.fromProduct(purchase('bad', price: -1)), isNull);
      expect(
        SpendingPurchase.fromProduct(purchase('unsaved', purchased: false)),
        isNull,
      );
    },
  );

  test(
    'LRU evicts least recent access, not least frequency or insertion order',
    () async {
      final calls = <String>[];
      final cache = MonthlySpendingCache(
        capacity: 2,
        worker: (r) async {
          calls.add(r.month);
          return calculateMonthlySpending(r);
        },
      );
      await cache.resolve('2026-01', []);
      await cache.resolve('2026-02', []);
      await cache.resolve('2026-01', []);
      await cache.resolve('2026-03', []);
      await cache.resolve('2026-01', []);
      await cache.resolve('2026-02', []);
      expect(calls, ['2026-01', '2026-02', '2026-03', '2026-02']);
      expect(cache.hits, 2);
    },
  );

  test(
    'deduplicates workers and ignores results invalidated while running',
    () async {
      final workers = <Completer<MonthlySpending>>[];
      final cache = MonthlySpendingCache(
        worker: (r) {
          final pending = Completer<MonthlySpending>();
          workers.add(pending);
          return pending.future;
        },
      );
      final old = cache.resolve('2026-11', []);
      expect(identical(cache.resolve('2026-11', []), old), isTrue);
      cache.invalidate();
      final fresh = cache.resolve('2026-11', []);
      workers[1].complete(MonthlySpending('2026-11', []));
      await fresh;
      workers[0].complete(MonthlySpending('old', []));
      await old;
      expect((await cache.resolve('2026-11', [])).month, '2026-11');
      expect(workers.length, 2);
    },
  );

  test('native compute worker agrees with pure calculation', () async {
    final result = await MonthlySpendingCache().resolve('2026-11', [
      SpendingPurchase.fromProduct(
        purchase('a', date: DateTime.utc(2026, 11, 10)),
      )!,
    ]);
    expect(result.totalCents, 1000);
    expect(result.count, 1);
  });

  test(
    'offline restart, partial cache, server replacement and account isolation',
    () async {
      final connectivity = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.offline);
      final store = MemorySpendingStore();
      await store.save(
        'u',
        SpendingSnapshot(
          syncedAt: DateTime.utc(2026, 11, 20),
          purchases: [
            SpendingPurchase.fromProduct(
              purchase('saved', date: DateTime.utc(2026, 11, 10)),
            )!,
          ],
        ),
      );
      final events = StreamController<OwnerProducts>.broadcast();
      var user = 'u';
      final c = MonthlySpendingController(
        ownerId: 'u',
        currentUserId: () => user,
        watchProducts: () => events.stream,
        connectivity: connectivity,
        store: store,
        cache: immediateCache(),
        now: () => DateTime.utc(2026, 11, 28, 12),
      );
      await c.start();
      expect(c.hasData, isTrue);
      expect(c.summary!.totalCents, 1000);
      expect(c.stale, isTrue);
      events.add(const OwnerProducts(products: [], fromCache: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.summary!.count, 1);
      events.add(const OwnerProducts(products: [], hasPendingWrites: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.pendingWrites, isTrue);
      expect((await store.load('u'))!.purchases.length, 1);
      connectivity.setStatus(NetworkStatus.available);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      events.add(
        OwnerProducts(
          products: [
            purchase('other', owner: 'other', date: DateTime.utc(2026, 11, 20)),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.summary!.count, 0);
      expect((await store.load('u'))!.purchases, isEmpty);
      expect(c.pendingWrites, isFalse);
      user = 'other';
      expect(c.summary, isNull);
      expect(c.hasData, isFalse);
      c.dispose();
      await events.close();
      connectivity.dispose();
    },
  );

  test(
    'no offline snapshot is unavailable rather than a zero-spend summary',
    () async {
      final connectivity = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.offline);
      final c = MonthlySpendingController(
        ownerId: 'u',
        currentUserId: () => 'u',
        watchProducts: () => const Stream.empty(),
        connectivity: connectivity,
        store: MemorySpendingStore(),
        cache: immediateCache(),
      );
      await c.start();
      expect(c.loading, isFalse);
      expect(c.hasData, isFalse);
      expect(c.summary, isNull);
      c.dispose();
      connectivity.dispose();
    },
  );
}
