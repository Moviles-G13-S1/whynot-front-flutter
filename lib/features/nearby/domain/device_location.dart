/// Domain model representing the device's current geographic location.
///
/// This object only exists in memory while the Context-Aware feature is
/// running. WhyNot does not persist the user's location in Firestore.
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;
}