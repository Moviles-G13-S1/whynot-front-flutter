import '../models/city.dart';
import '../models/user_profile.dart';
import 'live_section.dart';
import 'connectivity_status.dart';
import 'connection_recovery.dart';
import 'application_error_reporter.dart';

/// The city catalog starts alongside the profile subscription, rather than
/// waiting for the profile's first result. Photo resolution still depends on
/// the profile's photo path and remains in ProfileAvatar.
class ProfileLoadController {
  ProfileLoadController({
    required Stream<UserProfile?> Function() watchProfile,
    required Future<List<City>> Function() getCities,
    ConnectivityStatus? connectivity,
    ApplicationErrorReporter? errorReporter,
  }) : profile = LiveSection(
         watchProfile,
         onError: (error) => errorReporter?.report(
           error,
           feature: 'profile',
           operation: 'watch_profile',
         ),
       ),
       cities = LiveSection(
         () => Stream.fromFuture(getCities()),
         onError: (error) => errorReporter?.report(
           error,
           feature: 'profile',
           operation: 'load_cities',
         ),
       ) {
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
