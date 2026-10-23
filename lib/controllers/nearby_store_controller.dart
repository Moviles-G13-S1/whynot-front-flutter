import '../models/nearby_failure.dart';
import '../models/device_location.dart';
import '../models/repositories/location_repository.dart';
import '../models/nearby_store.dart';
import '../models/repositories/nearby_store_repository.dart';

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
  Future<NearbyStore?> getNearestStore({bool requestPermission = true}) async {
    final location = await _getLocation(requestPermission);
    try {
      return await _nearbyStoreRepository.getNearestStore(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (_) {
      throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
    }
  }

  Future<DeviceLocation> _getLocation(bool requestPermission) async {
    try {
      return await _locationRepository.getCurrentLocation(
        requestPermission: requestPermission,
      );
    } on NearbyFailure {
      rethrow;
    } catch (_) {
      throw const NearbyFailure(NearbyFailureKind.locationUnavailable);
    }
  }

  Future<bool> openAppSettings() => _locationRepository.openAppSettings();
  Future<bool> openLocationSettings() =>
      _locationRepository.openLocationSettings();
}
