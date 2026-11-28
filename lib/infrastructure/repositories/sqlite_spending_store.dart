import '../../models/monthly_spending.dart';
import '../../models/repositories/spending_store.dart';
import '../storage/whynot_local_database.dart';

/// Atomic, account-scoped copy of server-confirmed purchases, including empty sets.
class SqliteSpendingStore implements SpendingStore {
  SqliteSpendingStore(this.database);
  final WhyNotLocalDatabase database;

  void _validate(String userId) {
    if (userId.trim().isEmpty) throw ArgumentError('User ID required.');
  }

  @override
  Future<void> save(String userId, SpendingSnapshot snapshot) async {
    _validate(userId);
    final db = await database.open();
    await db.transaction((txn) async {
      await txn.delete(
        'spending_purchases',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final batch = txn.batch();
      for (final p in snapshot.purchases) {
        batch.insert('spending_purchases', {
          'user_id': userId,
          'product_id': p.id,
          'category_id': p.categoryId,
          'name': p.name,
          'brand': p.brand,
          'amount_cents': p.amountCents,
          'purchased_at': p.purchasedAt?.toUtc().millisecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
      await txn.rawInsert(
        'INSERT OR REPLACE INTO spending_sync (user_id, synced_at) VALUES (?, ?)',
        [userId, snapshot.syncedAt.toUtc().millisecondsSinceEpoch],
      );
    });
  }

  @override
  Future<SpendingSnapshot?> load(String userId) async {
    _validate(userId);
    final db = await database.open();
    return db.transaction((txn) async {
      final sync = await txn.query(
        'spending_sync',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (sync.isEmpty) return null;
      final rows = await txn.query(
        'spending_purchases',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return SpendingSnapshot(
        syncedAt: DateTime.fromMillisecondsSinceEpoch(
          sync.single['synced_at'] as int,
          isUtc: true,
        ),
        purchases: rows
            .map(
              (r) => SpendingPurchase(
                id: r['product_id'] as String,
                categoryId: r['category_id'] as String,
                name: r['name'] as String,
                brand: r['brand'] as String,
                amountCents: r['amount_cents'] as int,
                purchasedAt: r['purchased_at'] == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        r['purchased_at'] as int,
                        isUtc: true,
                      ),
              ),
            )
            .toList(),
      );
    });
  }

  @override
  Future<void> clear(String userId) async {
    _validate(userId);
    final db = await database.open();
    await db.transaction((txn) async {
      await txn.delete(
        'spending_purchases',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'spending_sync',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
  }
}
