import 'dart:math' as math;

import 'connectivity_status.dart';
import '../models/nearby_failure.dart';
import '../models/device_location.dart';
import '../models/repositories/location_repository.dart';
import '../models/nearby_store.dart';
import '../models/repositories/nearby_store_repository.dart';
import '../models/repositories/auth_repository.dart';

class NearbyStoreResult {
  const NearbyStoreResult(this.store, {this.stale = false});
  final NearbyStore? store;
  final bool stale;
}

/// Coordinates the Context-Aware nearby-store flow.
///
/// It first obtains the current device location and then asks the nearby-store
/// repository for the closest relevant store.
class NearbyStoreController {
  NearbyStoreController({
    required LocationRepository locationRepository,
    required NearbyStoreRepository nearbyStoreRepository,
    AuthRepository? authRepository,
    ConnectivityStatus? connectivity,
  }) : _locationRepository = locationRepository,
       _nearbyStoreRepository = nearbyStoreRepository,
       _authRepository = authRepository,
       connectivity = connectivity ?? ConnectivityStatus(observe: false);

  final LocationRepository _locationRepository;
  final NearbyStoreRepository _nearbyStoreRepository;
  final AuthRepository? _authRepository;
  final ConnectivityStatus connectivity;
  NearbyStore? _lastStore;
  DeviceLocation? _lastLocation;
  String? _lastUserId;
  String? _observedUserId;

  /// Returns the nearest relevant store for the device's current location.
  ///
  /// The coordinates are used only for this request and are not persisted.
  Future<NearbyStore?> getNearestStore({bool requestPermission = true}) async {
    return (await getNearestStoreResult(
      requestPermission: requestPermission,
    )).store;
  }

  Future<NearbyStoreResult> getNearestStoreResult({
    bool requestPermission = true,
    bool checkConnection = false,
  }) async {
    final userId = _authRepository?.currentUser?.id;
    if (_observedUserId != userId) {
      _lastStore = null;
      _lastLocation = null;
      _lastUserId = null;
      _observedUserId = userId;
    }
    final location = await _getLocation(requestPermission);
    if (_authRepository?.currentUser?.id != userId) {
      throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
    }
    if (connectivity.isOffline && !checkConnection) {
      final previous = _safePrevious(location, userId);
      if (previous != null) return NearbyStoreResult(previous, stale: true);
      throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
    }
    try {
      final store = await _nearbyStoreRepository.getNearestStore(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (_authRepository?.currentUser?.id != userId) {
        throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
      }
      _lastStore = store;
      _lastLocation = location;
      _lastUserId = userId;
      if (checkConnection) connectivity.confirmReachable();
      return NearbyStoreResult(store);
    } catch (_) {
      if (_authRepository?.currentUser?.id != userId) {
        throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
      }
      final previous = _safePrevious(location, userId);
      if (previous != null) return NearbyStoreResult(previous, stale: true);
      throw const NearbyFailure(NearbyFailureKind.nearbyServiceUnavailable);
    }
  }

  NearbyStore? _safePrevious(DeviceLocation current, String? userId) {
    final prior = _lastLocation;
    if (_lastStore == null || prior == null || _lastUserId != userId) {
      return null;
    }
    final latitudeDelta = (current.latitude - prior.latitude) * math.pi / 180;
    final longitudeDelta =
        (current.longitude - prior.longitude) * math.pi / 180;
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(prior.latitude * math.pi / 180) *
            math.cos(current.latitude * math.pi / 180) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final meters = 12742000 * math.asin(math.sqrt(a.toDouble()));
    return meters <= 100 ? _lastStore : null;
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
