import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_product_draft_store.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_recent_recommendation_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/catalog_product_details.dart';
import 'package:whynot_mobile/models/local_product_draft.dart';
import 'package:whynot_mobile/models/recent_recommendation.dart';

const _table = WhyNotLocalDatabase.recentRecommendationsTable;

RecentRecommendation entry(String id, {String? name}) => RecentRecommendation(
  sourceProductId: id,
  details: CatalogProductDetails(
    name: name ?? 'Product $id',
    brand: 'Brand',
    price: 12,
    imageUrl: '',
    productUrl: '',
    categoryId: 'fashion',
    reason: 'Popular with similar users.',
  ),
  // Simulate ties so eviction has to rely on SQLite's insertion order.
  openedAt: DateTime.utc(2026, 11, 25),
);

Iterable<String> sourceIds(List<RecentRecommendation> entries) =>
    entries.map((entry) => entry.sourceProductId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late WhyNotLocalDatabase database;
  late SqliteRecentRecommendationStore history;
  late String path;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('whynot-recent-');
    path = '${dir.path}/whynot_product_drafts.db';
    database = WhyNotLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    history = SqliteRecentRecommendationStore(database);
    addTearDown(() async {
      await database.close();
      await dir.delete(recursive: true);
    });
  });

  test(
    'v2 upgrade preserves drafts when both stores open concurrently',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => db.execute('''
          CREATE TABLE product_drafts (
            user_id TEXT NOT NULL,
            draft_scope TEXT NOT NULL,
            wishlist_id TEXT,
            category_id TEXT,
            wishlist_name TEXT,
            wishlist_emoji TEXT,
            name TEXT NOT NULL,
            brand TEXT NOT NULL,
            price_text TEXT NOT NULL,
            image_url TEXT NOT NULL,
            product_url TEXT NOT NULL,
            PRIMARY KEY (user_id, draft_scope)
          )
        '''),
        ),
      );
      for (final scope in ['general', 'wishlist:fashion']) {
        await old.insert('product_drafts', {
          'user_id': 'a',
          'draft_scope': scope,
          'wishlist_id': 'fashion',
          'category_id': 'fashion',
          'wishlist_name': 'Fashion',
          'wishlist_emoji': '👕',
          'name': scope,
          'brand': 'Test',
          'price_text': '12,',
          'image_url': 'https://example.com/item.png',
          'product_url': 'https://example.com/item',
        });
      }
      final oldDrafts = await old.query(
        'product_drafts',
        orderBy: 'draft_scope',
      );
      await old.close();

      final drafts = SqliteProductDraftStore.withDatabase(database);
      await Future.wait([history.record('a', entry('bag')), drafts.load('a')]);
      final db = await database.open();
      expect(await db.getVersion(), 5);
      expect(
        await db.query('product_drafts', orderBy: 'draft_scope'),
        oldDrafts,
      );
      expect(
        (await drafts.load('a', originWishlistId: 'fashion'))?.priceText,
        '12,',
      );
      expect(sourceIds(await history.read('a')), ['bag']);

      // Individual stores use the shared connection without closing each other.
      await drafts.close();
      await history.clear('a');
      expect((await drafts.load('a'))?.name, 'general');
      expect(await history.read('a'), isEmpty);
    },
  );

  test('reopens and prunes distinct rows within each UID', () async {
    await history.record('b', entry('1', name: 'Other account'));
    for (var i = 1; i <= 5; i++) {
      await history.record('a', entry('$i'));
    }
    await history.record('a', entry('1', name: 'Updated first'));
    await history.record('a', entry('6'));

    final db = await database.open();
    expect(
      await db.query(_table, where: 'user_id = ?', whereArgs: ['a']),
      hasLength(5),
    );
    final row = (await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: ['a'],
    )).first;
    expect(
      row.keys,
      unorderedEquals([
        'user_id',
        'source_product_id',
        'name',
        'brand',
        'price',
        'image_url',
        'product_url',
        'category_id',
        'reason',
        'opened_at',
        'open_order',
      ]),
    );
    final current = await history.read('a');
    expect(sourceIds(current), ['6', '1', '5', '4', '3']);
    expect(current[1].details.name, 'Updated first');
    expect(current[1].openedAt, DateTime.utc(2026, 11, 25));
    expect((await history.read('b')).single.details.name, 'Other account');

    await history.clear('a');
    expect(await history.read('a'), isEmpty);
    expect(sourceIds(await history.read('b')), ['1']);
  });

  test(
    'concurrent records never exceed five rows for either account',
    () async {
      await Future.wait([
        for (var i = 0; i < 12; i++) ...[
          history.record('a', entry('$i')),
          history.record('b', entry('$i')),
        ],
      ]);
      final db = await database.open();
      expect(await db.query(_table), hasLength(10));
      expect(await history.read('a'), hasLength(5));
      expect(await history.read('b'), hasLength(5));
    },
  );

  test(
    'late refresh only changes fields on the original retained visit',
    () async {
      final openOrder = await history.record('a', entry('bag'));
      await history.record('a', entry('hat'));
      final newDetails = entry('bag', name: 'Checked bag').details;
      await history.refreshDetails('a', 'bag', openOrder, newDetails);
      expect(sourceIds(await history.read('a')), ['hat', 'bag']);
      expect((await history.read('a')).last.details.name, 'Checked bag');

      await history.record('a', entry('bag', name: 'New visit'));
      await history.refreshDetails('a', 'bag', openOrder, newDetails);
      expect((await history.read('a')).first.details.name, 'New visit');
      await history.clear('a');
      await history.refreshDetails('a', 'bag', openOrder, newDetails);
      expect(await history.read('a'), isEmpty);
    },
  );

  test(
    'missing and corrupt rows do not hide valid history or drafts',
    () async {
      final drafts = SqliteProductDraftStore.withDatabase(database);
      await drafts.save(const LocalProductDraft(userId: 'a', name: 'Draft'));
      expect(await history.read('a'), isEmpty);
      await history.record('a', entry('good'));
      await history.record('a', entry('bad-name'));
      await history.record('a', entry('bad-date'));
      final db = await database.open();
      await db.update(_table, {
        'name': '',
      }, where: "source_product_id = 'bad-name'");
      await db.update(_table, {
        'opened_at': 9000000000000000,
      }, where: "source_product_id = 'bad-date'");
      expect(sourceIds(await history.read('a')), ['good']);
      expect((await drafts.load('a'))?.name, 'Draft');
      await expectLater(history.read(' '), throwsArgumentError);
    },
  );
}
