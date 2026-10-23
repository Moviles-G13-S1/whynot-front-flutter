import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../models/device_location.dart';
import '../../models/nearby_failure.dart';
import '../../models/repositories/location_repository.dart';

/// Geolocator implementation of [LocationRepository].
///
/// This repository is responsible for interacting with the device or browser
/// location APIs through the Geolocator package.
///
/// WhyNot only requests the current position when the Context-Aware feature
/// needs it. The coordinates are returned to the controller and are
/// not persisted by this repository.
class GeolocatorLocationRepository implements LocationRepository {
  /// Obtains the device's current geographic position.
  ///
  /// Before requesting the position, the repository verifies that location
  /// services are available and that the application has permission to use
  /// them.
  ///
  /// An exception is thrown when location cannot be accessed. The
  /// view can later translate these failures into a
  /// user-friendly state.
  @override
  Future<DeviceLocation> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const NearbyFailure(NearbyFailureKind.servicesDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const NearbyFailure(
          NearbyFailureKind.permissionPermanentlyDenied,
        );
      }
      if (permission == LocationPermission.denied) {
        throw const NearbyFailure(NearbyFailureKind.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on NearbyFailure {
      rethrow;
    } on LocationServiceDisabledException {
      throw const NearbyFailure(NearbyFailureKind.servicesDisabled);
    } on PermissionDeniedException {
      final permission = await Geolocator.checkPermission();
      throw NearbyFailure(
        permission == LocationPermission.deniedForever
            ? NearbyFailureKind.permissionPermanentlyDenied
            : NearbyFailureKind.permissionDenied,
      );
    } on TimeoutException {
      throw const NearbyFailure(NearbyFailureKind.locationUnavailable);
    } catch (_) {
      throw const NearbyFailure(NearbyFailureKind.locationUnavailable);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
