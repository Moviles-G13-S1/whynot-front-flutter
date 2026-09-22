import 'package:cloud_functions/cloud_functions.dart';

import '../domain/nearby_store.dart';
import '../domain/nearby_store_repository.dart';

/// Firebase implementation of [NearbyStoreRepository].
///
/// This repository sends the current latitude and longitude to the
/// `get_nearest_store` Firebase Cloud Function.
///
/// The backend is responsible for:
///
/// 1. Reading the current user's preferred category.
/// 2. Finding stores associated with that category.
/// 3. Calculating the distance to each candidate.
/// 4. Returning exactly one nearest store.
///
/// Firebase-specific details remain in the data layer and are not exposed to
/// controllers or presentation widgets.
class FirebaseNearbyStoreRepository implements NearbyStoreRepository {
  FirebaseNearbyStoreRepository({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Firebase Functions client used to communicate with the backend.
  ///
  /// Emulator configuration is handled globally during application startup
  /// rather than inside this repository.
  final FirebaseFunctions _functions;

  /// Requests the nearest relevant store for the supplied coordinates.
  ///
  /// The user's location is sent only as request data to the Cloud Function.
  /// This repository does not persist the coordinates in Firestore.
  ///
  /// A null result is valid and means that the backend did not find a store.
  @override
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  }) async {
    final callable = _functions.httpsCallable(
      'get_nearest_store',
    );

    final result = await callable.call({
      'latitude': latitude,
      'longitude': longitude,
    });

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    final rawStore = data['store'];

    // A null store is a valid backend response.
    if (rawStore == null) {
      return null;
    }

    final store = Map<String, dynamic>.from(
      rawStore as Map,
    );

    return NearbyStore(
      id: store['id'] as String,
      name: store['name'] as String,
      address: store['address'] as String,
      latitude: (store['latitude'] as num).toDouble(),
      longitude: (store['longitude'] as num).toDouble(),
      categoryIds: List<String>.from(
        store['categoryIds'] as List,
      ),
      websiteUrl: store['websiteUrl'] as String,
      imageUrl: store['imageUrl'] as String,
      distanceKm: (store['distanceKm'] as num).toDouble(),
    );
  }
}