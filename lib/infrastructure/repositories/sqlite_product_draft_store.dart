import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../models/local_product_draft.dart';

/// Persistent unfinished product forms, isolated by Firebase user AND entry.
///
/// A wishlist's Add Item button uses that wishlist as [originWishlistId].
/// The central Add button uses null and has a separate general draft, even
/// after the user picks a destination wishlist in the form.
class SqliteProductDraftStore {
  SqliteProductDraftStore({DatabaseFactory? factory, String? databasePath})
    : _injectedFactory = factory,
      _databasePathOverride = databasePath;

  static const _databaseName = 'whynot_product_drafts.db';
  static const _table = 'product_drafts';

  // Delay reading the platform database factory: widget tests that do not use
  // SQLite must not require native SQLite initialization.
  final DatabaseFactory? _injectedFactory;
  late final DatabaseFactory _factory =
      _injectedFactory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
  final String? _databasePathOverride;

  Future<Database>? _databaseFuture;

  Future<Database> _database() => _databaseFuture ??= _openDatabase();

  static String _scope(String? originWishlistId) {
    final id = originWishlistId?.trim();
    return id == null || id.isEmpty ? 'general' : 'wishlist:$id';
  }

  Future<Database> _openDatabase() async {
    final String path;
    if (_databasePathOverride != null) {
      path = _databasePathOverride;
    } else if (kIsWeb) {
      // sqflite_common_ffi_web persists the database in IndexedDB.
      path = _databaseName;
    } else {
      final directory = await getDatabasesPath();
      path = '$directory/$_databaseName';
    }

    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) => _createTable(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // v1 stored one row per user and did not record where the form
            // was opened. Preserve its data, assigning it to the selected
            // wishlist when possible; otherwise use the general draft.
            // This is a one-time best-effort migration of ambiguous v1 data.
            await db.execute('ALTER TABLE $_table RENAME TO product_drafts_v1');
            await _createTable(db);
            await db.execute('''
              INSERT INTO $_table (
                user_id, draft_scope, wishlist_id, category_id,
                wishlist_name, wishlist_emoji, name, brand,
                price_text, image_url, product_url
              )
              SELECT
                user_id,
                CASE
                  WHEN wishlist_id IS NOT NULL AND TRIM(wishlist_id) != ''
                  THEN 'wishlist:' || TRIM(wishlist_id)
                  ELSE 'general'
                END,
                wishlist_id, category_id, wishlist_name, wishlist_emoji,
                name, brand, price_text, image_url, product_url
              FROM product_drafts_v1
            ''');
            await db.execute('DROP TABLE product_drafts_v1');
          }
        },
      ),
    );
  }

  static Future<void> _createTable(Database db) => db.execute('''
    CREATE TABLE $_table (
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
  ''');

  /// [originWishlistId] is the wishlist used to OPEN the form, not necessarily
  /// the destination the user later selected using the central Add button.
  Future<void> save(LocalProductDraft draft, {String? originWishlistId}) async {
    _validateUserId(draft.userId);
    final db = await _database();
    await db.insert(_table, {
      'user_id': draft.userId,
      'draft_scope': _scope(originWishlistId),
      'wishlist_id': draft.wishlistId,
      'category_id': draft.categoryId,
      'wishlist_name': draft.wishlistName,
      'wishlist_emoji': draft.wishlistEmoji,
      'name': draft.name,
      'brand': draft.brand,
      'price_text': draft.priceText,
      'image_url': draft.imageUrl,
      'product_url': draft.productUrl,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<LocalProductDraft?> load(
    String userId, {
    String? originWishlistId,
  }) async {
    _validateUserId(userId);
    final db = await _database();
    final rows = await db.query(
      _table,
      where: 'user_id = ? AND draft_scope = ?',
      whereArgs: [userId, _scope(originWishlistId)],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return LocalProductDraft(
      userId: row['user_id'] as String,
      wishlistId: row['wishlist_id'] as String?,
      categoryId: row['category_id'] as String?,
      wishlistName: row['wishlist_name'] as String?,
      wishlistEmoji: row['wishlist_emoji'] as String?,
      name: row['name'] as String? ?? '',
      brand: row['brand'] as String? ?? '',
      priceText: row['price_text'] as String? ?? '',
      imageUrl: row['image_url'] as String? ?? '',
      productUrl: row['product_url'] as String? ?? '',
    );
  }

  /// Clear only the current form's draft, not other wishlists' drafts.
  Future<void> clear(String userId, {String? originWishlistId}) async {
    _validateUserId(userId);
    final db = await _database();
    await db.delete(
      _table,
      where: 'user_id = ? AND draft_scope = ?',
      whereArgs: [userId, _scope(originWishlistId)],
    );
  }

  Future<void> close() async {
    final pending = _databaseFuture;
    _databaseFuture = null;
    if (pending != null) {
      final db = await pending;
      await db.close();
    }
  }

  void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'A signed-in user ID is required.',
      );
    }
  }
}
