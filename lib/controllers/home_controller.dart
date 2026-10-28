import '../models/user_profile.dart';
import '../models/wishlist.dart';
import 'live_section.dart';

/// Runs the initial profile and wishlist subscriptions concurrently, then
/// continues observing live updates. No extra one-shot Firestore reads.
class HomeController {
  HomeController({
    required Stream<UserProfile?> Function() watchProfile,
    required Stream<List<WishlistSummary>> Function() watchWishlists,
  }) : profile = LiveSection(watchProfile),
       wishlists = LiveSection(watchWishlists) {
    profile.start();
    wishlists.start();
  }

  final LiveSection<UserProfile?> profile;
  final LiveSection<List<WishlistSummary>> wishlists;

  void dispose() {
    profile.dispose();
    wishlists.dispose();
  }
}
