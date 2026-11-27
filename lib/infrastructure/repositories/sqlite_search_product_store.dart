import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/product.dart';
import '../storage/whynot_local_database.dart';

/// Durable copy of the last server-confirmed product collection per account.
class SqliteSearchProductStore {
  SqliteSearchProductStore(this._database);

  final WhyNotLocalDatabase _database;
  static const _table = WhyNotLocalDatabase.searchProductsTable;

  Future<void> save(String userId, List<Product> products) async {
    _validateUser(userId);
    if (products.any((product) => product.ownerId != userId)) {
      throw ArgumentError('A snapshot must contain only this user’s products.');
    }
    final payload = jsonEncode(products.map(_encode).toList());
    final db = await _database.open();
    // Replace the entire collection atomically, including an empty collection.
    await db.insert(_table, {
      'user_id': userId,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Null means no saved snapshot; an empty list means a known empty collection.
  Future<List<Product>?> load(String userId) async {
    _validateUser(userId);
    final db = await _database.open();
    final rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload =
        jsonDecode(rows.single['payload'] as String) as List<dynamic>;
    final products = payload
        .map((row) => _decode(row as Map<String, dynamic>))
        .toList();
    if (products.any((product) => product.ownerId != userId)) {
      throw StateError('Stored product owner does not match the account.');
    }
    return List<Product>.unmodifiable(products);
  }

  Future<void> clear(String userId) async {
    _validateUser(userId);
    final db = await _database.open();
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }

  void _validateUser(String userId) {
    if (userId.trim().isEmpty) throw ArgumentError('A user ID is required.');
  }

  static Map<String, dynamic> _encode(Product p) => {
    'id': p.id,
    'ownerId': p.ownerId,
    'wishlistId': p.wishlistId,
    'categoryId': p.categoryId,
    'name': p.name,
    'brand': p.brand,
    'price': p.price,
    'imageUrl': p.imageUrl,
    'productUrl': p.productUrl,
    'purchased': p.purchased,
    'purchasedAt': p.purchasedAt?.toIso8601String(),
    'createdAt': p.createdAt?.toIso8601String(),
    'updatedAt': p.updatedAt?.toIso8601String(),
  };

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static Product _decode(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    ownerId: row['ownerId'] as String,
    wishlistId: row['wishlistId'] as String,
    categoryId: row['categoryId'] as String,
    name: row['name'] as String,
    brand: row['brand'] as String,
    price: (row['price'] as num).toDouble(),
    imageUrl: row['imageUrl'] as String,
    productUrl: row['productUrl'] as String,
    purchased: row['purchased'] as bool,
    purchasedAt: _date(row['purchasedAt']),
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}
