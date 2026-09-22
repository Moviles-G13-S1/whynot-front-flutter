import 'package:whynot_mobile/features/nearby/domain/nearby_store.dart';
import 'package:whynot_mobile/features/nearby/domain/nearby_store_repository.dart';

/// In-memory implementation of [NearbyStoreRepository] used by tests.
///
/// Tests can optionally provide a store to simulate a successful
/// Context-Aware backend response.
class InMemoryNearbyStoreRepository implements NearbyStoreRepository {
  InMemoryNearbyStoreRepository({
    this.store,
  });

  /// Store returned by [getNearestStore].
  ///
  /// A null value simulates the backend returning no nearby store.
  final NearbyStore? store;

  @override
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  }) async {
    return store;
  }
}