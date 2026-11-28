import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_spending_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/monthly_spending.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late WhyNotLocalDatabase database;
  late SqliteSpendingStore store;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spending_store_');
    path = '${directory.path}/local.db';
    database = WhyNotLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    store = SqliteSpendingStore(database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  SpendingSnapshot snapshot([String id = 'a']) => SpendingSnapshot(
    syncedAt: DateTime.utc(2026, 11, 28),
    purchases: [
      SpendingPurchase(
        id: id,
        categoryId: 'fashion',
        name: 'Coat',
        brand: 'Brand',
        amountCents: 12345,
        purchasedAt: DateTime.utc(2026, 11, 5),
      ),
    ],
  );

  test(
    'purchases and sync time survive restart; users and empty snapshots are distinct',
    () async {
      expect(await store.load('u'), isNull);
      await store.save('u', snapshot());
      await store.save('v', snapshot('b'));
      await database.close();
      database = WhyNotLocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      store = SqliteSpendingStore(database);
      final loaded = (await store.load('u'))!;
      expect(loaded.purchases.single.amountCents, 12345);
      expect(loaded.purchases.single.purchasedAt, DateTime.utc(2026, 11, 5));
      expect(loaded.syncedAt, DateTime.utc(2026, 11, 28));
      await store.save(
        'u',
        SpendingSnapshot(purchases: [], syncedAt: DateTime.utc(2026, 11, 29)),
      );
      expect((await store.load('u'))!.purchases, isEmpty);
      expect((await store.load('v'))!.purchases.single.id, 'b');
      await store.clear('u');
      expect(await store.load('u'), isNull);
      expect(await store.load('v'), isNotNull);
    },
  );

  test(
    'failed replacement rolls back purchases and metadata together',
    () async {
      await store.save('u', snapshot());
      final duplicate = snapshot().purchases.single;
      await expectLater(
        store.save(
          'u',
          SpendingSnapshot(
            purchases: [duplicate, duplicate],
            syncedAt: DateTime.utc(2030),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await store.load('u'))!.syncedAt, snapshot().syncedAt);
      expect((await store.load('u'))!.purchases.length, 1);
    },
  );

  test('v5 migration preserves all existing tables and their data', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          for (final name in [
            'product_drafts',
            'recent_recommendations',
            'store_summaries',
            'search_product_snapshots',
          ]) {
            await db.execute('CREATE TABLE $name (marker TEXT)');
            await db.insert(name, {'marker': 'keep'});
          }
        },
      ),
    );
    await old.close();
    final upgraded = await database.open();
    expect(await upgraded.getVersion(), 6);
    for (final name in [
      'product_drafts',
      'recent_recommendations',
      'store_summaries',
      'search_product_snapshots',
    ]) {
      expect((await upgraded.query(name)).single['marker'], 'keep');
    }
    await store.save('u', snapshot());
    expect((await store.load('u'))!.purchases.length, 1);
  });
}
