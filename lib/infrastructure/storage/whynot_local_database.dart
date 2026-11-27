import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Santiago Casasbuenas: Single schema owner for the existing draft database
/// and the separate recommendation history table. Both stores share the open
/// future in production, so the first caller runs the migrations exactly once.
class WhyNotLocalDatabase {
  WhyNotLocalDatabase({DatabaseFactory? factory, String? databasePath})
    : _injectedFactory = factory,
      _databasePathOverride = databasePath;

  static final shared = WhyNotLocalDatabase();
  static const _databaseName = 'whynot_product_drafts.db';
  static const productDraftsTable = 'product_drafts';
  static const recentRecommendationsTable = 'recent_recommendations';
  static const storeSummariesTable = 'store_summaries';
  static const searchProductsTable = 'search_product_snapshots';

  // Resolve the native factory only when SQLite is actually used.
  final DatabaseFactory? _injectedFactory;
  late final DatabaseFactory _factory =
      _injectedFactory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
  final String? _databasePathOverride;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= _openWithRetry();

  Future<Database> _openWithRetry() async {
    try {
      return await _openDatabase();
    } catch (_) {
      // A failed open must not poison a future attempt by either store.
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final String path;
    if (_databasePathOverride != null) {
      path = _databasePathOverride;
    } else if (kIsWeb) {
      // sqflite_common_ffi_web persists the database in IndexedDB.
      path = _databaseName;
    } else {
      final directory = await _factory.getDatabasesPath();
      path = '$directory/$_databaseName';
    }

    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          await _createDrafts(db);
          await _createHistory(db);
          await _createStoreSummaries(db);
          await _createSearchProducts(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeDraftsFromV1(db);
          if (oldVersion < 3) await _createHistory(db);
          if (oldVersion < 4) await _createStoreSummaries(db);
          if (oldVersion < 5) await _createSearchProducts(db);
        },
      ),
    );
  }

  static Future<void> _upgradeDraftsFromV1(Database db) async {
    // v1 stored one row per user and did not record where the form
    // was opened. Preserve its data, assigning it to the selected
    // wishlist when possible; otherwise use the general draft.
    // This is a one-time best-effort migration of ambiguous v1 data.
    await db.execute(
      'ALTER TABLE $productDraftsTable RENAME TO product_drafts_v1',
    );
    await _createDrafts(db);
    await db.execute('''
      INSERT INTO $productDraftsTable (
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

  static Future<void> _createDrafts(Database db) => db.execute('''
    CREATE TABLE $productDraftsTable (
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

  // Santiago Casasbuenas: History contains only account/source identity and
  // display fields. The generated order remains stable for ties or clock changes.
  static Future<void> _createHistory(Database db) async {
    await db.execute('''
      CREATE TABLE $recentRecommendationsTable (
        open_order INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        source_product_id TEXT NOT NULL,
        opened_at INTEGER NOT NULL,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        price REAL NOT NULL CHECK (price >= 0),
        image_url TEXT NOT NULL,
        product_url TEXT NOT NULL,
        category_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        UNIQUE (user_id, source_product_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX recent_recommendations_by_user
      ON $recentRecommendationsTable (user_id, open_order DESC)
    ''');
  }

  // Santiago Casasbuenas: The last Stores grouping per account, so the view
  // opens instantly and still works offline after the app restarts.
  static Future<void> _createStoreSummaries(Database db) => db.execute('''
    CREATE TABLE $storeSummariesTable (
      user_id TEXT PRIMARY KEY,
      computed_at INTEGER NOT NULL,
      payload TEXT NOT NULL
    )
  ''');

  // Account-scoped, complete search snapshots; empty snapshots are valid.
  static Future<void> _createSearchProducts(Database db) => db.execute('''
    CREATE TABLE $searchProductsTable (
      user_id TEXT PRIMARY KEY,
      payload TEXT NOT NULL
    )
  ''');

  /// Called by the owner once its stores have finished using the connection.
  Future<void> close() async {
    final pending = _opening;
    if (pending == null) return;
    final db = await pending;
    await db.close();
    _opening = null;
  }
}
