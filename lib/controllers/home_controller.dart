import '../models/user_profile.dart';
import '../models/wishlist.dart';
import 'live_section.dart';
import 'connectivity_status.dart';
import 'connection_recovery.dart';
import 'application_error_reporter.dart';

/// Runs the initial profile and wishlist subscriptions concurrently, then
/// continues observing live updates. No extra one-shot Firestore reads.
class HomeController {
  HomeController({
    required Stream<UserProfile?> Function() watchProfile,
    required Stream<List<WishlistSummary>> Function() watchWishlists,
    ConnectivityStatus? connectivity,
    ApplicationErrorReporter? errorReporter,
  }) : profile = LiveSection(
         watchProfile,
         onError: (error) => errorReporter?.report(
           error,
           feature: 'home',
           operation: 'load_profile',
         ),
       ),
       wishlists = LiveSection(
         watchWishlists,
         onError: (error) => errorReporter?.report(
           error,
           feature: 'home',
           operation: 'load_wishlists',
         ),
       ) {
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
