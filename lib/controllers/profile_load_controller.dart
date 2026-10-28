import '../models/city.dart';
import '../models/user_profile.dart';
import 'live_section.dart';
import 'connectivity_status.dart';
import 'connection_recovery.dart';

/// The city catalog starts alongside the profile subscription, rather than
/// waiting for the profile's first result. Photo resolution still depends on
/// the profile's photo path and remains in ProfileAvatar.
class ProfileLoadController {
  ProfileLoadController({
    required Stream<UserProfile?> Function() watchProfile,
    required Future<List<City>> Function() getCities,
    ConnectivityStatus? connectivity,
  }) : profile = LiveSection(watchProfile),
       cities = LiveSection(() => Stream.fromFuture(getCities())) {
    profile.start();
    cities.start();
    _recovery = ConnectionRecovery(connectivity, retryFailed);
  }

  final LiveSection<UserProfile?> profile;
  final LiveSection<List<City>> cities;
  late final ConnectionRecovery _recovery;

  void retryFailed() {
    if (profile.snapshot.hasError) profile.start();
    if (cities.snapshot.hasError) cities.start();
  }

  void dispose() {
    _recovery.dispose();
    profile.dispose();
    cities.dispose();
  }
}
