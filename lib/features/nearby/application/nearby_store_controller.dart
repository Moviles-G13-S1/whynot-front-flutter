import '../domain/location_repository.dart';
import '../domain/nearby_store.dart';
import '../domain/nearby_store_repository.dart';

/// Coordinates the Context-Aware nearby-store flow.
///
/// It first obtains the current device location and then asks the nearby-store
/// repository for the closest relevant store.
class NearbyStoreController {
  const NearbyStoreController({
    required LocationRepository locationRepository,
    required NearbyStoreRepository nearbyStoreRepository,
  }) : _locationRepository = locationRepository,
       _nearbyStoreRepository = nearbyStoreRepository;

  final LocationRepository _locationRepository;
  final NearbyStoreRepository _nearbyStoreRepository;

  /// Returns the nearest relevant store for the device's current location.
  ///
  /// The coordinates are used only for this request and are not persisted.
  Future<NearbyStore?> getNearestStore() async {
    final location = await _locationRepository.getCurrentLocation();

    return _nearbyStoreRepository.getNearestStore(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }
}