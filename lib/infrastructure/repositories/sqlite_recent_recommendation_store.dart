import 'package:sqflite/sqflite.dart';

import '../../models/catalog_product_details.dart';
import '../../models/recent_recommendation.dart';
import '../../models/repositories/recent_recommendation_store.dart';
import '../storage/whynot_local_database.dart';

class SqliteRecentRecommendationStore implements RecentRecommendationStore {
  const SqliteRecentRecommendationStore(this._database);

  static const _table = WhyNotLocalDatabase.recentRecommendationsTable;
  static const _whereUser = 'user_id = ?';
  final WhyNotLocalDatabase _database;

  // Santiago Casasbuenas: Reopening moves an item to the top, and each UID can
  // retain five distinct products. Upsert and eviction commit together.
  static const _capacity = 5;

  @override
  Future<int> record(String userId, RecentRecommendation entry) async {
    _requireUser(userId);
    final fields = _displayFields(entry.details);
    if (entry.sourceProductId.trim().isEmpty) {
      throw ArgumentError('A source product ID is required.');
    }
    final db = await _database.open();
    return db.transaction((txn) async {
      final order = await txn.insert(_table, {
        'user_id': userId,
        'source_product_id': entry.sourceProductId,
        'opened_at': entry.openedAt.millisecondsSinceEpoch,
        ...fields,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        _table,
        where:
            '''
          $_whereUser AND open_order IN (
            SELECT open_order FROM $_table WHERE $_whereUser
            ORDER BY open_order DESC LIMIT -1 OFFSET ?
          )
        ''',
        whereArgs: [userId, userId, _capacity],
      );
      return order;
    });
  }

  @override
  Future<void> refreshDetails(
    String userId,
    String sourceProductId,
    int openOrder,
    CatalogProductDetails details,
  ) async {
    _requireUser(userId);
    final fields = _displayFields(details);
    final db = await _database.open();
    await db.update(
      _table,
      fields,
      where: '$_whereUser AND source_product_id = ? AND open_order = ?',
      whereArgs: [userId, sourceProductId, openOrder],
    );
  }

  Map<String, Object> _displayFields(CatalogProductDetails details) {
    if (details.name.trim().isEmpty ||
        !details.price.isFinite ||
        details.price < 0) {
      throw ArgumentError('Invalid recommendation history details.');
    }
    return {
      'name': details.name,
      'brand': details.brand,
      'price': details.price,
      'image_url': details.imageUrl,
      'product_url': details.productUrl,
      'category_id': details.categoryId,
      'reason': details.reason,
    };
  }

  @override
  Future<List<RecentRecommendation>> read(String userId) async {
    _requireUser(userId);
    final db = await _database.open();
    final rows = await db.query(
      _table,
      where: _whereUser,
      whereArgs: [userId],
      orderBy: 'open_order DESC',
      limit: _capacity,
    );
    return rows.map(_decode).nonNulls.toList(growable: false);
  }

  RecentRecommendation? _decode(Map<String, Object?> row) {
    final id = row['source_product_id'];
    final openedAt = row['opened_at'];
    final name = row['name'];
    final price = row['price'];
    if (id is! String ||
        id.trim().isEmpty ||
        openedAt is! int ||
        openedAt < -8640000000000000 ||
        openedAt > 8640000000000000 ||
        name is! String ||
        name.trim().isEmpty ||
        price is! num ||
        !price.isFinite ||
        price < 0) {
      return null;
    }
    return RecentRecommendation(
      sourceProductId: id,
      openedAt: DateTime.fromMillisecondsSinceEpoch(openedAt, isUtc: true),
      details: CatalogProductDetails(
        name: name,
        price: price.toDouble(),
        brand: _text(row['brand']),
        imageUrl: _text(row['image_url']),
        productUrl: _text(row['product_url']),
        categoryId: _text(row['category_id']),
        reason: _text(row['reason']),
      ),
    );
  }

  String _text(Object? value) => value is String ? value : '';

  @override
  Future<void> clear(String userId) async {
    _requireUser(userId);
    final db = await _database.open();
    await db.delete(_table, where: _whereUser, whereArgs: [userId]);
  }

  void _requireUser(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('A signed-in user ID is required.');
    }
  }
}
