import 'package:geolocator/geolocator.dart';

import '../domain/device_location.dart';
import '../domain/location_repository.dart';

/// Geolocator implementation of [LocationRepository].
///
/// This repository is responsible for interacting with the device or browser
/// location APIs through the Geolocator package.
///
/// WhyNot only requests the current position when the Context-Aware feature
/// needs it. The coordinates are returned to the application layer and are
/// not persisted by this repository.
class GeolocatorLocationRepository implements LocationRepository {
  /// Obtains the device's current geographic position.
  ///
  /// Before requesting the position, the repository verifies that location
  /// services are available and that the application has permission to use
  /// them.
  ///
  /// An exception is thrown when location cannot be accessed. The
  /// presentation layer can later translate these failures into a
  /// user-friendly state.
  @override
  Future<DeviceLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();

    // Ask for permission when it has not been granted yet.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // The user denied the permission request.
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    // The user permanently denied location access.
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission was permanently denied.',
      );
    }

    // Obtain the current position only after permission is available.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}