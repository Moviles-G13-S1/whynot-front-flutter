import 'package:whynot_mobile/features/nearby/domain/device_location.dart';
import 'package:whynot_mobile/features/nearby/domain/location_repository.dart';

/// In-memory implementation of [LocationRepository] used by tests.
///
/// It returns a predefined location without requesting device permissions
/// or accessing platform location services.
class InMemoryLocationRepository implements LocationRepository {
  InMemoryLocationRepository({
    this.location = const DeviceLocation(
      latitude: 4.6669,
      longitude: -74.0531,
    ),
  });

  /// Location returned whenever the application requests the current
  /// position during a test.
  final DeviceLocation location;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    return location;
  }
}