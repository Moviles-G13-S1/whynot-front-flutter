import 'nearby_store.dart';

/// Domain contract for obtaining the Context-Aware store recommendation.
///
/// The repository receives the user's current coordinates and delegates the
/// store-selection logic to the backend.
///
/// The domain layer does not know that Firebase Cloud Functions is used by
/// the concrete implementation.
abstract interface class NearbyStoreRepository {
  /// Returns the nearest relevant store for the supplied coordinates.
  ///
  /// A null result is valid and means the backend could not find any store.
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  });
}