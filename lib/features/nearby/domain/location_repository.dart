import 'device_location.dart';

/// Domain contract for obtaining the device's current location.
///
/// The domain layer does not know which package or platform API is used to
/// obtain the location. The concrete implementation will use Geolocator.
///
/// Location is only requested when needed and is not persisted by WhyNot.
abstract interface class LocationRepository {
  /// Returns the device's current geographic location.
  ///
  /// Implementations may throw when location services are disabled,
  /// permissions are denied, or the position cannot be obtained.
  Future<DeviceLocation> getCurrentLocation();
}