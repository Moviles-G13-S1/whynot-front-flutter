import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/stores_controller.dart';
import 'package:whynot_mobile/infrastructure/repositories/file_store_preferences_store.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_store_summary_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/repositories/store_preferences_store.dart';
import 'package:whynot_mobile/models/repositories/store_summary_store.dart';
import 'package:whynot_mobile/models/store_summary.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/views/screens/store_detail_screen.dart';
import 'package:whynot_mobile/views/screens/stores_screen.dart';
import 'package:whynot_mobile/views/widgets/cover_resize_image.dart';
import 'package:whynot_mobile/views/widgets/store_logo.dart';

Product _product(
  String id, {
  String url = '',
  String brand = 'Brand',
  double price = 100,
  bool purchased = false,
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
);

OwnerProducts _live(List<Product> products) =>
    OwnerProducts(products: products);

OwnerProducts _cached(List<Product> products, {bool pending = false}) =>
    OwnerProducts(
      products: products,
      fromCache: true,
      hasPendingWrites: pending,
    );

StoreSummary _saved(String domain, String brand, DateTime at) =>
    groupProductsByStore((
      products: [_product('old', url: domain, brand: brand)],
      computedAt: at,
    ));

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

class _MemoryPreferences implements StorePreferencesStore {
  final saved = <String, StoreSort>{};
  int writes = 0;
  Completer<void>? holdReads;

  @override
  Future<StoreSort?> readSort(String userId) async {
    await holdReads?.future;
    return saved[userId];
  }

  @override
  Future<void> writeSort(String userId, StoreSort sort) async {
    writes++;
    saved[userId] = sort;
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

  group('micro-optimization helpers', () {
    test('equal products give equal grouping keys', () {
      final a = [_product('1', url: 'zara.com'), _product('2')];
      final b = [_product('1', url: 'zara.com'), _product('2')];
      expect(storeGroupingKey(a), storeGroupingKey(b));
      expect(
        storeGroupingKey([_product('1', url: 'zara.com', purchased: true)]),
        isNot(storeGroupingKey([_product('1', url: 'zara.com')])),
      );
    });

    test('withComputedAt keeps the same groups', () {
      final summary = _saved('zara.com', 'Zara', DateTime(2026));
      final again = summary.withComputedAt(DateTime(2027));
      expect(identical(again.groups, summary.groups), isTrue);
      expect(again.computedAt, DateTime(2027));
    });

    test('cover decoding keeps the ratio and fills the box', () {
      // The measured product photo: 2696 x 1198 in a 192 px thumbnail.
      expect(coverDecodeSize(2696, 1198, 192), (width: 432, height: 192));
      expect(coverDecodeSize(600, 1000, 192), (width: 192, height: 320));
      expect(coverDecodeSize(100, 50, 192), (width: 100, height: 50));
    });

    testWidgets('CoverResizeImage decodes at the cover size', (tester) async {
      final info = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 400, 200),
          Paint()..color = const Color(0xFF336699),
        );
        final source = await recorder.endRecording().toImage(400, 200);
        final png = await source.toByteData(format: ui.ImageByteFormat.png);
        final provider = CoverResizeImage(
          MemoryImage(png!.buffer.asUint8List()),
          size: 50,
        );
        final completer = Completer<ImageInfo>();
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener((info, _) => completer.complete(info)),
            );
        return completer.future;
      });
      expect(info!.image.width, 100);
      expect(info.image.height, 50);
    });

    test('images are decoded at the size they are drawn', () {
      expect(decodeWidthFor(40 * 0.72, 3), 87);
      expect(decodeWidthFor(64, 3), 192);
      expect(decodeWidthFor(64, 2), 128);
    });
  });

  group('Stores sort (Sprint 4 local storage)', () {
    final summary = groupProductsByStore((
      products: [
        _product('1', url: 'zara.com', brand: 'Zara', price: 10),
        _product('2', url: 'zara.com', brand: 'Zara', price: 10),
        _product('3', url: 'apple.com', brand: 'Apple', price: 900),
        _product('4', url: 'hm.com', brand: 'H&M', price: 50),
      ],
      computedAt: DateTime(2026),
    ));
    List<String> order(StoreSort sort) => [
      for (final group in sortStoreGroups(summary.groups, sort)) group.domain,
    ];

    test('orders by products, value still to buy, or name', () {
      expect(order(StoreSort.products), ['zara.com', 'apple.com', 'hm.com']);
      expect(order(StoreSort.pendingValue), [
        'apple.com',
        'hm.com',
        'zara.com',
      ]);
      expect(order(StoreSort.name), ['apple.com', 'hm.com', 'zara.com']);
      expect(
        identical(
          sortStoreGroups(summary.groups, StoreSort.products),
          summary.groups,
        ),
        isTrue,
      );
    });

    test('names round-trip and unknown names are ignored', () {
      for (final sort in StoreSort.values) {
        expect(StoreSort.fromName(sort.name), sort);
      }
      expect(StoreSort.fromName('price'), isNull);
      expect(StoreSort.fromName(null), isNull);
    });

    group('FileStorePreferencesStore', () {
      late Directory directory;
      late FileStorePreferencesStore store;

      setUp(() async {
        directory = await Directory.systemTemp.createTemp('stores_prefs_');
        addTearDown(() => directory.delete(recursive: true));
        store = FileStorePreferencesStore(
          directory: () async => directory,
          now: () => DateTime.utc(2026, 11, 27, 10),
        );
      });

      test('writes one JSON file per account and reads it back', () async {
        await store.writeSort('user-1', StoreSort.pendingValue);
        await store.writeSort('user-2', StoreSort.name);

        expect(await store.readSort('user-1'), StoreSort.pendingValue);
        expect(await store.readSort('user-2'), StoreSort.name);
        expect(await store.readSort('user-3'), isNull);
        final file = File('${directory.path}/stores_preferences/user-1.json');
        expect(jsonDecode(await file.readAsString()), {
          'version': 1,
          'userId': 'user-1',
          'sort': 'pendingValue',
          'updatedAt': '2026-11-27T10:00:00.000Z',
        });
        expect(File('${file.path}.tmp').existsSync(), isFalse);
      });

      test('a later choice replaces the earlier one', () async {
        await store.writeSort('user-1', StoreSort.name);
        await store.writeSort('user-1', StoreSort.products);
        expect(await store.readSort('user-1'), StoreSort.products);
      });

      test('corrupt, foreign or unknown files read as no preference', () async {
        final file = await store.fileFor('user-1');
        await file.parent.create(recursive: true);
        await file.writeAsString('{not json');
        expect(await store.readSort('user-1'), isNull);
        await file.writeAsString('{"userId":"someone-else","sort":"name"}');
        expect(await store.readSort('user-1'), isNull);
        await file.writeAsString('{"userId":"user-1","sort":"price"}');
        expect(await store.readSort('user-1'), isNull);
      });

      test('file names cannot leave the folder', () async {
        final file = await store.fileFor('../../etc/x');
        expect(
          file.path,
          '${directory.path}/stores_preferences/______etc_x.json',
        );
      });

      test('clear removes the account file only', () async {
        await store.writeSort('user-1', StoreSort.name);
        await store.writeSort('user-2', StoreSort.name);
        await store.clear('user-1');
        expect(await store.readSort('user-1'), isNull);
        expect(await store.readSort('user-2'), StoreSort.name);
      });
    });
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
    late StreamController<OwnerProducts> products;
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
      products = StreamController<OwnerProducts>.broadcast();
      store = _MemoryStore();
    });

    test('shows the device copy first, then the server grouping', () async {
      store.saved['user-1'] = _saved('hm.com', 'H&M', DateTime(2026));
      final controller = create()..start();
      await pumpEventQueue();
      expect(controller.source, StoresSource.device);
      expect(controller.mayBeOutdated, isTrue);
      expect(controller.confirmedAt, DateTime(2026));

      products.add(_live([_product('1', url: 'zara.com', brand: 'Zara')]));
      await pumpEventQueue();
      expect(controller.source, StoresSource.live);
      expect(controller.summary!.groups.single.domain, 'zara.com');
      expect(controller.mayBeOutdated, isFalse);
      expect(controller.confirmedAt!.isAfter(DateTime(2026)), isTrue);
      expect(store.saved['user-1']!.groups.single.domain, 'zara.com');
    });

    test(
      'cached products are shown but never saved as the device copy',
      () async {
        final controller = create()..start();
        products.add(_cached([_product('1', url: 'zara.com')]));
        await pumpEventQueue();
        expect(controller.source, StoresSource.cache);
        expect(controller.mayBeOutdated, isTrue);
        expect(store.writes, 0);
      },
    );

    test('an empty cache keeps the device copy', () async {
      store.saved['user-1'] = _saved('hm.com', 'H&M', DateTime(2026));
      final controller = create()..start();
      await pumpEventQueue();
      products.add(_cached(const []));
      await pumpEventQueue();
      expect(controller.source, StoresSource.device);
      expect(controller.summary!.groups.single.domain, 'hm.com');
      expect(store.writes, 0);
    });

    test(
      'offline with nothing stored waits instead of showing no products',
      () async {
        connectivity.setStatus(NetworkStatus.offline);
        final controller = create()..start();
        products.add(_cached(const []));
        await pumpEventQueue();
        expect(controller.summary, isNull);
        expect(controller.cacheWasEmpty, isTrue);
        expect(controller.waitingForConnection, isTrue);
        expect(store.writes, 0);
      },
    );

    test('an empty server answer is a real empty state and is saved', () async {
      final controller = create()..start();
      products.add(_cached(const []));
      products.add(_live(const []));
      await pumpEventQueue();
      expect(controller.source, StoresSource.live);
      expect(controller.summary!.totalProducts, 0);
      expect(store.saved['user-1']!.totalProducts, 0);
    });

    test('pending writes are reported', () async {
      final controller = create()..start();
      products.add(_cached([_product('1', url: 'zara.com')], pending: true));
      await pumpEventQueue();
      expect(controller.hasPendingWrites, isTrue);
    });

    test(
      'a failed refresh keeps the last grouping and reports the error',
      () async {
        final controller = create()..start();
        products.add(_live([_product('1', url: 'zara.com')]));
        await pumpEventQueue();
        products.addError(StateError('permission-denied'));
        await pumpEventQueue();
        expect(controller.summary!.groups.single.domain, 'zara.com');
        expect(controller.error, isNotNull);
      },
    );

    test('a slow older grouping never replaces a newer one', () async {
      final pending = <Completer<StoreSummary>>[];
      final inputs = <StoreGroupingInput>[];
      final controller = create(
        grouper: (input) {
          inputs.add(input);
          return (pending..add(Completer())).last.future;
        },
      )..start();
      products.add(_live([_product('1', url: 'hm.com')]));
      products.add(_live([_product('2', url: 'zara.com')]));
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

    group('sort preference', () {
      late _MemoryPreferences preferences;
      var userId = 'user-1';

      StoresController createWithPreferences() {
        final controller = StoresController(
          watchProducts: () => products.stream,
          currentUserId: () => userId,
          connectivity: connectivity,
          store: store,
          preferences: preferences,
          grouper: _syncGrouper,
        );
        addTearDown(controller.dispose);
        return controller;
      }

      setUp(() {
        preferences = _MemoryPreferences();
        userId = 'user-1';
      });

      test('restores the saved order and orders the visible stores', () async {
        preferences.saved['user-1'] = StoreSort.name;
        final controller = createWithPreferences()..start();
        products.add(
          _live([
            _product('1', url: 'zara.com', brand: 'Zara'),
            _product('2', url: 'zara.com', brand: 'Zara'),
            _product('3', url: 'apple.com', brand: 'Apple'),
          ]),
        );
        await pumpEventQueue();
        expect(controller.sort, StoreSort.name);
        expect(controller.visibleGroups.map((g) => g.domain), [
          'apple.com',
          'zara.com',
        ]);
        expect(
          identical(controller.visibleGroups, controller.visibleGroups),
          isTrue,
        );
      });

      test('a new choice is saved for the account', () async {
        final controller = createWithPreferences()..start();
        await pumpEventQueue();
        controller.setSort(StoreSort.pendingValue);
        await pumpEventQueue();
        expect(controller.sort, StoreSort.pendingValue);
        expect(preferences.saved['user-1'], StoreSort.pendingValue);
        controller.setSort(StoreSort.pendingValue);
        expect(preferences.writes, 1);
      });

      test('a choice made before the file is read is kept', () async {
        preferences
          ..saved['user-1'] = StoreSort.name
          ..holdReads = Completer<void>();
        final controller = createWithPreferences()..start();
        controller.setSort(StoreSort.pendingValue);
        preferences.holdReads!.complete();
        await pumpEventQueue();
        expect(controller.sort, StoreSort.pendingValue);
      });

      test('another account gets its own order', () async {
        preferences.saved['user-1'] = StoreSort.name;
        final controller = createWithPreferences()..start();
        await pumpEventQueue();
        expect(controller.sort, StoreSort.name);
        userId = 'user-2';
        controller.start();
        await pumpEventQueue();
        expect(controller.sort, StoreSort.products);
      });
    });

    group('micro-optimization: identical snapshots are not regrouped', () {
      test('cache then server with the same products groups once', () async {
        var groupings = 0;
        final controller = create(
          grouper: (input) async {
            groupings++;
            return groupProductsByStore(input);
          },
        )..start();
        final items = [_product('1', url: 'zara.com', brand: 'Zara')];
        products.add(_cached(items));
        await pumpEventQueue();
        final cachedGroups = controller.summary!.groups;
        expect(store.writes, 0);

        products.add(_live(items));
        await pumpEventQueue();
        expect(groupings, 1);
        expect(controller.source, StoresSource.live);
        expect(controller.mayBeOutdated, isFalse);
        expect(identical(controller.summary!.groups, cachedGroups), isTrue);
        expect(controller.confirmedAt, controller.summary!.computedAt);
        // The server confirmation still refreshes the device copy.
        expect(store.writes, 1);
      });

      test(
        'refreshing with unchanged products needs no new grouping',
        () async {
          var groupings = 0;
          final controller = create(
            grouper: (input) async {
              groupings++;
              return groupProductsByStore(input);
            },
          )..start();
          final items = [_product('1', url: 'zara.com')];
          products.add(_live(items));
          await pumpEventQueue();
          await controller.retry();
          products.add(_cached(items));
          products.add(_live(items));
          await pumpEventQueue();
          expect(groupings, 1);
          expect(controller.source, StoresSource.live);
        },
      );

      test('a changed product is grouped again', () async {
        var groupings = 0;
        final controller = create(
          grouper: (input) async {
            groupings++;
            return groupProductsByStore(input);
          },
        )..start();
        products.add(_live([_product('1', url: 'zara.com', price: 10)]));
        await pumpEventQueue();
        products.add(_live([_product('1', url: 'zara.com', price: 20)]));
        await pumpEventQueue();
        expect(groupings, 2);
        expect(controller.summary!.groups.single.pendingValue, 20);
      });

      test('the device copy is never treated as grouped products', () async {
        store.saved['user-1'] = _saved('zara.com', 'Zara', DateTime(2026));
        var groupings = 0;
        final controller = create(
          grouper: (input) async {
            groupings++;
            return groupProductsByStore(input);
          },
        )..start();
        await pumpEventQueue();
        products.add(_live([_product('old', url: 'zara.com', brand: 'Zara')]));
        await pumpEventQueue();
        expect(groupings, 1);
        expect(controller.source, StoresSource.live);
      });
    });
  });

  test('sync age reads naturally', () {
    final now = DateTime(2026, 11, 25, 12);
    expect(describeSyncAge(now, now), 'just now');
    expect(
      describeSyncAge(now.subtract(const Duration(minutes: 5)), now),
      '5 min ago',
    );
    expect(
      describeSyncAge(now.subtract(const Duration(hours: 2)), now),
      '2 h ago',
    );
    expect(
      describeSyncAge(now.subtract(const Duration(days: 1)), now),
      'yesterday',
    );
    expect(
      describeSyncAge(now.subtract(const Duration(days: 3)), now),
      '3 days ago',
    );
  });

  group('Stores screens', () {
    late ConnectivityStatus connectivity;
    late StreamController<OwnerProducts> products;
    late StoresController controller;

    setUp(() {
      connectivity = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.offline);
      products = StreamController<OwnerProducts>.broadcast();
      controller = StoresController(
        watchProducts: () => products.stream,
        currentUserId: () => 'user-1',
        connectivity: connectivity,
        grouper: _syncGrouper,
      );
      addTearDown(controller.dispose);
    });

    Future<void> pumpStores(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: StoresScreen(controller: controller, loadLogos: false),
        routes: {
          AppRoutes.storeDetail: (_) =>
              const StoreDetailScreen(loadImages: false),
        },
      ),
    );

    testWidgets('offline with nothing stored asks to reconnect', (
      tester,
    ) async {
      await pumpStores(tester);
      products.add(_cached(const []));
      await tester.pump();

      expect(
        find.text(
          'Your stores will appear when you reconnect to Wi-Fi or mobile data.',
        ),
        findsOneWidget,
      );
      expect(find.text('You haven’t saved any products yet.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('store tiles are not rebuilt when only the notice changes', (
      tester,
    ) async {
      connectivity.setStatus(NetworkStatus.available);
      await pumpStores(tester);
      final items = [_product('1', url: 'zara.com', brand: 'Zara')];
      products.add(_cached(items));
      await tester.pump();
      await tester.pump();
      final before = tester.widget(
        find.byKey(const ValueKey('store-zara.com')),
      );
      expect(find.text('Saved information'), findsOneWidget);

      products.add(_live(items));
      await tester.pump();
      await tester.pump();
      expect(find.text('Saved information'), findsNothing);
      final after = tester.widget(find.byKey(const ValueKey('store-zara.com')));
      expect(identical(before, after), isTrue);
    });

    testWidgets('Sort by chips reorder the stores', (tester) async {
      await pumpStores(tester);
      products.add(
        _cached([
          _product('1', url: 'zara.com', brand: 'Zara', price: 10),
          _product('2', url: 'zara.com', brand: 'Zara', price: 10),
          _product('3', url: 'apple.com', brand: 'Apple', price: 900),
        ]),
      );
      await tester.pump();
      await tester.pump();
      double top(String domain) =>
          tester.getTopLeft(find.byKey(ValueKey('store-$domain'))).dy;
      expect(top('zara.com'), lessThan(top('apple.com')));

      await tester.tap(find.byKey(const ValueKey('stores-sort-pendingValue')));
      await tester.pump();
      expect(controller.sort, StoreSort.pendingValue);
      expect(top('apple.com'), lessThan(top('zara.com')));
    });

    testWidgets('lists cached stores with an offline notice', (tester) async {
      await pumpStores(tester);
      products.add(
        _cached([
          _product('1', url: 'zara.com', brand: 'Zara', price: 50),
          _product('2', url: 'zara.com', brand: 'Zara', price: 70),
          _product('3'),
        ]),
      );
      await tester.pump();

      expect(find.text('Zara'), findsOneWidget);
      expect(find.byType(StoreLogo), findsOneWidget);
      expect(find.text('2 products'), findsOneWidget);
      expect(find.text('\$120'), findsOneWidget);
      expect(find.text('1 product has no usable store link.'), findsOneWidget);
      expect(
        find.text('Showing your saved stores; they may be outdated.'),
        findsOneWidget,
      );
    });

    testWidgets('the store page updates when the server answers', (
      tester,
    ) async {
      await pumpStores(tester);
      products.add(_cached([_product('1', url: 'zara.com', brand: 'Zara')]));
      await tester.pump();
      await tester.tap(find.text('Zara'));
      await tester.pumpAndSettle();
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('You’re offline'), findsOneWidget);

      connectivity.setStatus(NetworkStatus.available);
      products.add(
        _live([
          _product('1', url: 'zara.com', brand: 'Zara'),
          _product('2', url: 'zara.com', brand: 'Zara'),
        ]),
      );
      await tester.pump();
      expect(find.text('Product 2'), findsOneWidget);
      expect(find.text('2 saved · \$200 still to buy'), findsOneWidget);
      expect(find.text('You’re offline'), findsNothing);

      products.add(_live(const []));
      // Grouping is asynchronous: one frame for the event, one for the result.
      await tester.pump();
      await tester.pump();
      expect(
        find.text('No saved products from this store right now.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed refresh shows Try again over the loaded stores', (
      tester,
    ) async {
      connectivity.setStatus(NetworkStatus.available);
      await pumpStores(tester);
      products.add(_live([_product('1', url: 'zara.com', brand: 'Zara')]));
      await tester.pump();
      products.addError(StateError('unavailable'));
      await tester.pump();

      expect(find.text('Couldn’t refresh your stores'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Zara'), findsOneWidget);
    });
  });
}

Future<StoreSummary> _syncGrouper(StoreGroupingInput input) async =>
    _sync(input);
