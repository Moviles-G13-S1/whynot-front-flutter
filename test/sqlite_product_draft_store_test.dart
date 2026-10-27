import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_product_draft_store.dart';
import 'package:whynot_mobile/models/local_product_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('general, Fashion and Gifts drafts stay independent', () async {
    final directory = await Directory.systemTemp.createTemp('whynot-scopes-');
    final store = SqliteProductDraftStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/drafts.db',
    );
    try {
      // A central + draft may have Fashion chosen as its destination.
      // Its origin is still central, not the Fashion wishlist button.
      await store.save(const LocalProductDraft(
        userId: 'juli',
        wishlistId: 'fashion',
        name: 'Started with central +',
      ));
      await store.save(
        const LocalProductDraft(
          userId: 'juli',
          wishlistId: 'fashion',
          name: 'Started inside Fashion',
          priceText: '12,',
        ),
        originWishlistId: 'fashion',
      );
      await store.save(
        const LocalProductDraft(
          userId: 'juli',
          wishlistId: 'gifts',
          name: 'Started inside Gifts',
        ),
        originWishlistId: 'gifts',
      );

      expect((await store.load('juli'))!.name, 'Started with central +');
      expect(
        (await store.load('juli', originWishlistId: 'fashion'))!.name,
        'Started inside Fashion',
      );
      expect(
        (await store.load('juli', originWishlistId: 'fashion'))!.priceText,
        '12,',
      );
      expect(
        (await store.load('juli', originWishlistId: 'gifts'))!.name,
        'Started inside Gifts',
      );
      expect(await store.load('other-user', originWishlistId: 'fashion'), isNull);

      await store.clear('juli', originWishlistId: 'fashion');
      expect(await store.load('juli', originWishlistId: 'fashion'), isNull);
      expect((await store.load('juli'))!.name, 'Started with central +');
      expect(
        (await store.load('juli', originWishlistId: 'gifts'))!.name,
        'Started inside Gifts',
      );
    } finally {
      await store.close();
      await directory.delete(recursive: true);
    }
  });

  test('v1 existing Fashion draft is migrated without deleting its text', () async {
    final directory = await Directory.systemTemp.createTemp('whynot-migration-');
    final path = '${directory.path}/drafts.db';
    final oldDb = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE product_drafts (
              user_id TEXT PRIMARY KEY NOT NULL,
              wishlist_id TEXT,
              category_id TEXT,
              wishlist_name TEXT,
              wishlist_emoji TEXT,
              name TEXT NOT NULL,
              brand TEXT NOT NULL,
              price_text TEXT NOT NULL,
              image_url TEXT NOT NULL,
              product_url TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await oldDb.insert('product_drafts', {
      'user_id': 'juli',
      'wishlist_id': 'fashion',
      'category_id': 'fashion-cat',
      'wishlist_name': 'Fashion',
      'wishlist_emoji': null,
      'name': 'Old fashion draft',
      'brand': 'Old brand',
      'price_text': '45,',
      'image_url': '',
      'product_url': '',
    });
    await oldDb.close();

    final store = SqliteProductDraftStore(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    try {
      final fashion = await store.load('juli', originWishlistId: 'fashion');
      expect(fashion?.name, 'Old fashion draft');
      expect(fashion?.priceText, '45,');
      expect(await store.load('juli'), isNull);
    } finally {
      await store.close();
      await directory.delete(recursive: true);
    }
  });
}
