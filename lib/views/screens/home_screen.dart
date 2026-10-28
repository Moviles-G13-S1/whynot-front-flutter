import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/brand_mark.dart';
import '../widgets/nearby_store_section.dart';
import '../../controllers/home_controller.dart';
import '../widgets/smart_recommendation_section.dart';
import '../widgets/home_content.dart';
import '../widgets/form_controls.dart';

/// Main feed containing the user's wishlists and personalized features.
///
/// The Home screen is responsible only for composing the different sections.
/// Data access and application operations remain in models and controllers.
///
/// Current personalized sections:
///
/// - Context-Aware nearby store recommendation.
/// - Smart demographic product recommendation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeController? _loads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loads ??= HomeController(
      watchProfile: context.dependencies.profileController.watchCurrentProfile,
      watchWishlists:
          context.dependencies.wishlistController.watchCurrentSummaries,
    );
  }

  @override
  void dispose() {
    _loads?.dispose();
    super.dispose();
  }

  /// Extracts the first name from the user's full profile name.
  ///
  /// An empty string is returned when no valid name is available.
  String _firstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return '';
    }

    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final profileController = context.dependencies.profileController;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 42, 0, 132),
              sliver: SliverList.list(
                children: [
                  const BrandMark(),

                  const SizedBox(height: 46),

                  // --------------------------------------------------
                  // USER GREETING
                  // --------------------------------------------------
                  //
                  // Uses the real profile stored for the authenticated user.
                  if (profileController.currentUserId != null)
                    AnimatedBuilder(
                      animation: _loads!.profile,
                      builder: (context, _) {
                        final snapshot = _loads!.profile.snapshot;
                        if (snapshot.hasError) {
                          return TextButton(
                            onPressed: _loads!.profile.start,
                            child: const Text(
                              'Could not load your profile. Try again',
                            ),
                          );
                        }
                        final fullName = snapshot.data?.name;
                        final firstName = _firstName(fullName);

                        return Text(
                          firstName.isEmpty
                              ? 'Good Morning'
                              : 'Good Morning, $firstName',
                          style: WhyNotTextStyles.serif(size: 27),
                        );
                      },
                    )
                  else
                    Text(
                      'Good Morning',
                      style: WhyNotTextStyles.serif(size: 27),
                    ),

                  const SizedBox(height: 6),

                  Text(
                    'What are we saving today?',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),

                  const SizedBox(height: 38),

                  // --------------------------------------------------
                  // USER WISHLISTS
                  // --------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: HomeSectionHeader(
                      title: 'Your Wishlists',
                      action: 'View all',
                      onAction: () {
                        Navigator.pushNamed(context, AppRoutes.wishlists);
                      },
                    ),
                  ),

                  const SizedBox(height: 29),

                  AnimatedBuilder(
                    animation: _loads!.wishlists,
                    builder: (context, _) => WishlistRail(
                      snapshot: _loads!.wishlists.snapshot,
                      onRetry: _loads!.wishlists.start,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Santiago Casasbuenas: A separate catalog makes a cold
                  // recommendation fetch and a cached revisit visible.
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: PillButton(
                      label: 'Explore recommendations',
                      height: 44,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.recommendationCatalog,
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // --------------------------------------------------
                  // CONTEXT-AWARE FEATURE
                  // --------------------------------------------------
                  //
                  // NearbyStoreSection obtains the current device location
                  // through NearbyStoreController and displays the nearest
                  // relevant store returned by the backend.
                  //
                  // The user's coordinates are used only for the request and
                  // are not persisted by WhyNot.
                  Text('Near you', style: WhyNotTextStyles.muted(size: 13)),

                  const SizedBox(height: 20),

                  Text(
                    'Nearby recommendations',
                    style: WhyNotTextStyles.serif(size: 23),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'A nearby store based on your preferences.',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),

                  const SizedBox(height: 16),

                  const Padding(
                    padding: EdgeInsets.only(right: 30),
                    child: NearbyStoreSection(),
                  ),

                  const SizedBox(height: 54),

                  // --------------------------------------------------
                  // SMART RECOMMENDATION FEATURE
                  // --------------------------------------------------
                  //
                  // SmartRecommendationSection handles its own loading,
                  // empty, error, and success states while keeping Firebase
                  // access outside the Home screen.
                  Text(
                    'Top pick for you',
                    style: WhyNotTextStyles.serif(size: 23),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'A personalized recommendation based on users like you.',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),

                  const SizedBox(height: 17),

                  const Padding(
                    padding: EdgeInsets.only(right: 35),
                    child: SmartRecommendationSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
    );
  }
}
