import '../models/city.dart';
import '../models/user_profile.dart';
import 'live_section.dart';

/// The city catalog starts alongside the profile subscription, rather than
/// waiting for the profile's first result. Photo resolution still depends on
/// the profile's photo path and remains in ProfileAvatar.
class ProfileLoadController {
  ProfileLoadController({
    required Stream<UserProfile?> Function() watchProfile,
    required Future<List<City>> Function() getCities,
  }) : profile = LiveSection(watchProfile),
       cities = LiveSection(() => Stream.fromFuture(getCities())) {
    profile.start();
    cities.start();
  }

  final LiveSection<UserProfile?> profile;
  final LiveSection<List<City>> cities;

  void dispose() {
    profile.dispose();
    cities.dispose();
  }
}
