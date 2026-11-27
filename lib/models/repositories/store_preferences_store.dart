import '../store_summary.dart';

/// Santiago Casasbuenas: Sprint 4 local storage. The Stores view preferences
/// of each account, kept on this device.
abstract interface class StorePreferencesStore {
  /// The saved order, or null when none was saved or it cannot be read.
  Future<StoreSort?> readSort(String userId);

  Future<void> writeSort(String userId, StoreSort sort);

  Future<void> clear(String userId);
}
