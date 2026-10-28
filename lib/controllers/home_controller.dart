import '../models/user_profile.dart';
import '../models/wishlist.dart';
import 'live_section.dart';
import 'connectivity_status.dart';
import 'connection_recovery.dart';

/// Runs the initial profile and wishlist subscriptions concurrently, then
/// continues observing live updates. No extra one-shot Firestore reads.
class HomeController {
  HomeController({
    required Stream<UserProfile?> Function() watchProfile,
    required Stream<List<WishlistSummary>> Function() watchWishlists,
    ConnectivityStatus? connectivity,
  }) : profile = LiveSection(watchProfile),
       wishlists = LiveSection(watchWishlists) {
    profile.start();
    wishlists.start();
    _recovery = ConnectionRecovery(connectivity, retryFailed);
  }

  final LiveSection<UserProfile?> profile;
  final LiveSection<List<WishlistSummary>> wishlists;
  late final ConnectionRecovery _recovery;

  void retryFailed() {
    if (profile.snapshot.hasError) profile.start();
    if (wishlists.snapshot.hasError) wishlists.start();
  }

  void dispose() {
    _recovery.dispose();
    profile.dispose();
    wishlists.dispose();
  }
}
