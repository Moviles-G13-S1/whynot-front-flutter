import 'package:sqflite/sqflite.dart';

import '../../models/local_product_draft.dart';
import '../storage/whynot_local_database.dart';

/// Persistent unfinished product forms, isolated by Firebase user AND entry.
///
/// A wishlist's Add Item button uses that wishlist as [originWishlistId].
/// The central Add button uses null and has a separate general draft, even
/// after the user picks a destination wishlist in the form.
class SqliteProductDraftStore {
  SqliteProductDraftStore({DatabaseFactory? factory, String? databasePath})
    : _ownsDatabase = factory != null || databasePath != null,
      _database = factory == null && databasePath == null
          ? WhyNotLocalDatabase.shared
          : WhyNotLocalDatabase(factory: factory, databasePath: databasePath);

  SqliteProductDraftStore.withDatabase(this._database) : _ownsDatabase = false;

  static const _table = WhyNotLocalDatabase.productDraftsTable;
  final WhyNotLocalDatabase _database;
  final bool _ownsDatabase;

  static String _scope(String? originWishlistId) {
    final id = originWishlistId?.trim();
    return id == null || id.isEmpty ? 'general' : 'wishlist:$id';
  }

  /// [originWishlistId] is the wishlist used to OPEN the form, not necessarily
  /// the destination the user later selected using the central Add button.
  Future<void> save(LocalProductDraft draft, {String? originWishlistId}) async {
    _validateUserId(draft.userId);
    final db = await _database.open();
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
    final db = await _database.open();
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
    final db = await _database.open();
    await db.delete(
      _table,
      where: 'user_id = ? AND draft_scope = ?',
      whereArgs: [userId, _scope(originWishlistId)],
    );
  }

  Future<void> close() async {
    if (_ownsDatabase) await _database.close();
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
