import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/repositories/store_summary_store.dart';
import '../../models/store_summary.dart';
import '../storage/whynot_local_database.dart';

/// Santiago Casasbuenas: Keeps one row per UID with the last Stores grouping.
class SqliteStoreSummaryStore implements StoreSummaryStore {
  const SqliteStoreSummaryStore(this._database);

  static const _table = WhyNotLocalDatabase.storeSummariesTable;
  final WhyNotLocalDatabase _database;

  @override
  Future<StoreSummary?> read(String userId) async {
    _requireUser(userId);
    final db = await _database.open();
    final rows = await db.query(
      _table,
      columns: ['payload'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final json = jsonDecode(rows.single['payload'] as String);
      return StoreSummary.fromJson(Map<String, Object?>.from(json as Map));
    } catch (_) {
      // A corrupt row is only a cache miss; the next grouping replaces it.
      return null;
    }
  }

  @override
  Future<void> write(String userId, StoreSummary summary) async {
    _requireUser(userId);
    final db = await _database.open();
    await db.insert(_table, {
      'user_id': userId,
      'computed_at': summary.computedAt.millisecondsSinceEpoch,
      'payload': jsonEncode(summary.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear(String userId) async {
    _requireUser(userId);
    final db = await _database.open();
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }

  static void _requireUser(String userId) {
    if (userId.trim().isEmpty) throw ArgumentError('A user ID is required.');
  }
}
