import '../monthly_spending.dart';

abstract interface class SpendingStore {
  Future<SpendingSnapshot?> load(String userId);
  Future<void> save(String userId, SpendingSnapshot snapshot);
  Future<void> clear(String userId);
}
