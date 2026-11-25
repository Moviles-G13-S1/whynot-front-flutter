import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/stores_controller.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_store_summary_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/repositories/store_summary_store.dart';
import 'package:whynot_mobile/models/store_summary.dart';
import 'package:whynot_mobile/views/screens/stores_screen.dart';
import 'package:whynot_mobile/views/widgets/store_logo.dart';

Product _product(
  String id, {
  String url = '',
  String brand = 'Brand',
  double price = 100,
  bool purchased = false,
  bool fromCache = false,
}) => Product(
  id: id,
  ownerId: 'user-1',
  wishlistId: 'w1',
  categoryId: 'fashion',
  name: 'Product $id',
  brand: brand,
  price: price,
  imageUrl: '',
  productUrl: url,
  purchased: purchased,
  fromCache: fromCache,
);

StoreSummary _sync(StoreGroupingInput input) => groupProductsByStore(input);

class _MemoryStore implements StoreSummaryStore {
  final saved = <String, StoreSummary>{};
  int writes = 0;

  @override
  Future<StoreSummary?> read(String userId) async => saved[userId];

  @override
  Future<void> write(String userId, StoreSummary summary) async {
    writes++;
    saved[userId] = summary;
  }

  @override
  Future<void> clear(String userId) async => saved.remove(userId);
}

void main() {
  group('normalizeStoreDomain (same cases as the backend BQ)', () {
    test('reduces links to the registrable domain', () {
      expect(normalizeStoreDomain('https://www2.hm.com/es_co/x'), 'hm.com');
      expect(normalizeStoreDomain('hm.com/es_co'), 'hm.com');
      expect(normalizeStoreDomain('HTTPS://Shop.Zara.COM./co'), 'zara.com');
      expect(
        normalizeStoreDomain('https://www.falabella.com.co/p/1'),
        'falabella.com.co',
      );
      expect(normalizeStoreDomain('https://amazon.co.uk/dp/1'), 'amazon.co.uk');
    });

    test('rejects links that are not store pages', () {
      for (final url in [
        '',
        '   ',
        'mailto:info@zara.com',
        'ftp://zara.com/file',
        'https://192.168.0.1/x',
        'http://localhost:8080',
        'zara com',
        'https://zara.c0m',
      ]) {
        expect(normalizeStoreDomain(url), isNull, reason: url);
      }
    });
  });

  test('store names use the shared brand, else the domain label', () {
    expect(
      storeNameFor('goldengoose.com', ['Golden Goose', 'golden goose']),
      'Golden Goose',
    );
    expect(
      storeNameFor('mercado-libre.com', ['Apple', 'Sony']),
      'Mercado Libre',
    );
    expect(storeNameFor('amazon.com', const []), 'Amazon');
    // A reseller keeps its own name even when one brand fills it.
    expect(storeNameFor('cettire.com', ['Golden Goose']), 'Cettire');
    expect(storeNameFor('ebay.com', ['eBay']), 'eBay');
  });

  test('logos are requested by store domain only', () {
    final url = storeLogoUrl('goldengoose.com');
    expect(url.host, 'www.google.com');
    expect(url.queryParameters, {'domain': 'goldengoose.com', 'sz': '128'});
  });

  test('prices use thousands separators', () {
    expect(formatStorePrice(2500000), '\$2.500.000');
    expect(formatStorePrice(999), '\$999');
    expect(formatStorePrice(1234.5), '\$1.234,50');
  });

  test('groups and ranks products by store', () {
    final summary = groupProductsByStore((
      products: [
        _product('1', url: 'https://zara.com/a', brand: 'Zara', price: 50),
        _product('2', url: 'zara.com/b', brand: 'Zara', price: 70),
        _product(
          '3',
          url: 'https://www.zara.com/c',
          brand: 'ZARA',
          purchased: true,
        ),
        _product('4', url: 'https://hm.com/a', brand: 'H&M', price: 900),
        _product('5', url: 'https://amazon.com/a', brand: 'Sony', price: 10),
        _product('6'),
        _product('7', url: 'mailto:x@zara.com'),
      ],
      computedAt: DateTime(2026, 11, 25),
    ));

    expect(summary.totalProducts, 7);
    expect(summary.withoutLink, 1);
    expect(summary.invalidLink, 1);
    expect(summary.linkedProducts, 5);
    expect(summary.groups.map((g) => g.domain), [
      'zara.com',
      'hm.com', // tie with amazon.com broken by pending value
      'amazon.com',
    ]);
    final zara = summary.groups.first;
    expect(zara.name, 'Zara');
    expect(zara.productCount, 3);
    expect(zara.purchasedCount, 1);
    expect(zara.pendingValue, 120);
  });

  test('the background isolate returns the same grouping', () async {
    final input = (
      products: [
        for (var i = 0; i < 500; i++)
          _product('$i', url: 'https://store${i % 7}.com/p/$i'),
      ],
      computedAt: DateTime(2026, 11, 25),
    );
    final onIsolate = await groupOnBackgroundIsolate(input);
    final local = groupProductsByStore(input);
    expect(onIsolate.toJson(), local.toJson());
    expect(onIsolate.groups, hasLength(7));
  });

  test('a summary survives a JSON round trip', () {
    final summary = groupProductsByStore((
      products: [_product('1', url: 'zara.com', brand: 'Zara')],
      computedAt: DateTime(2026, 11, 25, 10),
    ));
    final copy = StoreSummary.fromJson(summary.toJson());
    expect(copy.toJson(), summary.toJson());
    expect(copy.computedAt, DateTime(2026, 11, 25, 10));
  });

  group('SqliteStoreSummaryStore', () {
    setUpAll(sqfliteFfiInit);

    late WhyNotLocalDatabase database;
    late String path;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('whynot-stores-');
      path = '${dir.path}/whynot_product_drafts.db';
      database = WhyNotLocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(() async {
        await database.close();
        await dir.delete(recursive: true);
      });
    });

    test('stores one summary per account', () async {
      final store = SqliteStoreSummaryStore(database);
      final summary = groupProductsByStore((
        products: [_product('1', url: 'zara.com', brand: 'Zara')],
        computedAt: DateTime(2026, 11, 25),
      ));
      await store.write('user-1', summary);

      expect((await store.read('user-1'))!.groups.single.name, 'Zara');
      expect(await store.read('user-2'), isNull);
      await store.clear('user-1');
      expect(await store.read('user-1'), isNull);
    });

    test('the v4 upgrade adds the table and keeps earlier data', () async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) => db.execute('CREATE TABLE marker (id INTEGER)'),
        ),
      );
      await old.insert('marker', {'id': 1});
      await old.close();

      final store = SqliteStoreSummaryStore(database);
      await store.write(
        'user-1',
        groupProductsByStore((products: const [], computedAt: DateTime(2026))),
      );
      final db = await database.open();
      expect(await db.query('marker'), hasLength(1));
      expect(await store.read('user-1'), isNotNull);
    });
  });

  group('StoresController', () {
    late ConnectivityStatus connectivity;
    late StreamController<List<Product>> products;
    late _MemoryStore store;

    StoresController create({StoreGrouper grouper = _syncGrouper}) {
      final controller = StoresController(
        watchProducts: () => products.stream,
        currentUserId: () => 'user-1',
        connectivity: connectivity,
        store: store,
        grouper: grouper,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    setUp(() {
      connectivity = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.available);
      products = StreamController<List<Product>>.broadcast();
      store = _MemoryStore();
    });

    test('shows the device copy first, then the server grouping', () async {
      store.saved['user-1'] = groupProductsByStore((
        products: [_product('old', url: 'hm.com', brand: 'H&M')],
        computedAt: DateTime(2026),
      ));
      final controller = create()..start();
      await pumpEventQueue();
      expect(controller.source, StoresSource.device);
      expect(controller.mayBeOutdated, isTrue);

      products.add([_product('1', url: 'zara.com', brand: 'Zara')]);
      await pumpEventQueue();
      expect(controller.source, StoresSource.live);
      expect(controller.summary!.groups.single.domain, 'zara.com');
      expect(controller.mayBeOutdated, isFalse);
      expect(store.saved['user-1']!.groups.single.domain, 'zara.com');
    });

    test(
      'cached products are shown but never saved as the device copy',
      () async {
        final controller = create()..start();
        products.add([_product('1', url: 'zara.com', fromCache: true)]);
        await pumpEventQueue();
        expect(controller.source, StoresSource.cache);
        expect(controller.mayBeOutdated, isTrue);
        expect(store.writes, 0);
      },
    );

    test('offline with an empty cache keeps the device copy', () async {
      connectivity.setStatus(NetworkStatus.offline);
      store.saved['user-1'] = groupProductsByStore((
        products: [_product('old', url: 'hm.com', brand: 'H&M')],
        computedAt: DateTime(2026),
      ));
      final controller = create()..start();
      await pumpEventQueue();
      products.add(const []);
      await pumpEventQueue();
      expect(controller.source, StoresSource.device);
      expect(controller.summary!.groups.single.domain, 'hm.com');
    });

    test('a slow older grouping never replaces a newer one', () async {
      final pending = <Completer<StoreSummary>>[];
      final inputs = <StoreGroupingInput>[];
      final controller = create(
        grouper: (input) {
          inputs.add(input);
          return (pending..add(Completer())).last.future;
        },
      )..start();
      products.add([_product('1', url: 'hm.com')]);
      products.add([_product('2', url: 'zara.com')]);
      await pumpEventQueue();

      pending[1].complete(groupProductsByStore(inputs[1]));
      await pumpEventQueue();
      pending[0].complete(groupProductsByStore(inputs[0]));
      await pumpEventQueue();
      expect(controller.summary!.groups.single.domain, 'zara.com');
    });

    test('reconnecting subscribes again for fresh products', () async {
      var subscriptions = 0;
      final controller = StoresController(
        watchProducts: () {
          subscriptions++;
          return products.stream;
        },
        currentUserId: () => 'user-1',
        connectivity: connectivity,
        grouper: _syncGrouper,
      );
      addTearDown(controller.dispose);
      controller.start();
      connectivity.setStatus(NetworkStatus.offline);
      expect(controller.isOffline, isTrue);
      connectivity.setStatus(NetworkStatus.available);
      expect(subscriptions, 2);
    });
  });

  testWidgets('Stores screen lists stores and flags offline data', (
    tester,
  ) async {
    final connectivity = ConnectivityStatus(observe: false)
      ..setStatus(NetworkStatus.offline);
    final products = StreamController<List<Product>>();
    final controller = StoresController(
      watchProducts: () => products.stream,
      currentUserId: () => 'user-1',
      connectivity: connectivity,
      grouper: _syncGrouper,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: StoresScreen(controller: controller, loadLogos: false)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Your stores will appear when you reconnect.'),
      findsOneWidget,
    );

    products.add([
      _product('1', url: 'zara.com', brand: 'Zara', price: 50, fromCache: true),
      _product('2', url: 'zara.com', brand: 'Zara', price: 70, fromCache: true),
      _product('3', fromCache: true),
    ]);
    await tester.pump();

    expect(find.text('Zara'), findsOneWidget);
    expect(find.byType(StoreLogo), findsOneWidget);
    expect(find.text('2 products'), findsOneWidget);
    expect(find.text('\$120'), findsOneWidget);
    expect(find.text('1 product has no usable store link.'), findsOneWidget);
    expect(
      find.text('Showing your saved stores. They may be outdated.'),
      findsOneWidget,
    );
  });
}

Future<StoreSummary> _syncGrouper(StoreGroupingInput input) async =>
    _sync(input);
