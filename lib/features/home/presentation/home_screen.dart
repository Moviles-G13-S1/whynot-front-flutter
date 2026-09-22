import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../nearby/presentation/nearby_store_section.dart';
import '../../profile/domain/user_profile.dart';
import '../../recommendations/presentation/smart_recommendation_section.dart';
import 'widgets/home_content.dart';

/// Main feed containing the user's wishlists and personalized features.
///
/// The Home screen is responsible only for composing the different sections.
/// Feature-specific behavior remains inside their respective presentation,
/// application, domain, and data layers.
///
/// Current personalized sections:
///
/// - Context-Aware nearby store recommendation.
/// - Smart demographic product recommendation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(
                18,
                42,
                0,
                132,
              ),
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
                    StreamBuilder<UserProfile?>(
                      stream: profileController.watchCurrentProfile(),
                      builder: (context, snapshot) {
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
                        Navigator.pushNamed(
                          context,
                          AppRoutes.wishlists,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 29),

                  const WishlistRail(),

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
                  Text(
                    'Near you',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),

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
      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 0,
      ),
    );
  }
}