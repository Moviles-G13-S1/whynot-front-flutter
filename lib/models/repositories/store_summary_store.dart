import '../store_summary.dart';

/// Santiago Casasbuenas: Device copy of the last Stores grouping per account.
abstract interface class StoreSummaryStore {
  Future<StoreSummary?> read(String userId);

  Future<void> write(String userId, StoreSummary summary);

  Future<void> clear(String userId);
}
