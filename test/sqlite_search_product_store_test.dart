import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_search_product_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/product.dart';

Product item(String owner, String id) => Product(
  id: id,
  ownerId: owner,
  wishlistId: 'wishlist',
  categoryId: 'technology',
  name: 'AirPods',
  brand: 'Apple',
  price: 249.99,
  imageUrl: '',
  productUrl: '',
  purchased: true,
  purchasedAt: DateTime.utc(2026, 11, 27),
);

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late WhyNotLocalDatabase database;
  late SqliteSearchProductStore store;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('search_snapshot_test');
    path = '${dir.path}/local.db';
    database = WhyNotLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    store = SqliteSearchProductStore(database);
  });
  tearDown(() async {
    await database.close();
    await dir.delete(recursive: true);
  });
  test('products and fields survive database close and reopen', () async {
    await store.save('a', [item('a', '1')]);
    await database.close();
    database = WhyNotLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    store = SqliteSearchProductStore(database);
    final p = (await store.load('a'))!.single;
    expect(p.id, '1');
    expect(p.price, 249.99);
    expect(p.purchased, isTrue);
    expect(p.purchasedAt, DateTime.utc(2026, 11, 27));
  });
  test('accounts are isolated and clear only deletes one user', () async {
    await store.save('a', [item('a', '1')]);
    await store.save('b', [item('b', '2')]);
    await store.clear('a');
    expect(await store.load('a'), isNull);
    expect((await store.load('b'))!.single.id, '2');
  });
  test(
    'replacement removes deleted products and persists empty lists',
    () async {
      expect(await store.load('a'), isNull);
      await store.save('a', [item('a', '1'), item('a', '2')]);
      await store.save('a', [item('a', '2')]);
      expect((await store.load('a'))!.map((p) => p.id), ['2']);
      await store.save('a', []);
      expect(await store.load('a'), isEmpty);
    },
  );
  test('rejects mixed-account snapshots', () async {
    await expectLater(store.save('a', [item('b', '2')]), throwsArgumentError);
    expect(await store.load('a'), isNull);
  });
}
