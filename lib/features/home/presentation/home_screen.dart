import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/brand_mark.dart';
import 'widgets/home_content.dart';

/// Main feed containing wishlists and future product recommendations.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _firstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return '';
    }

    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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

                  // Real user name from Firestore.
                  if (user != null)
                    StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();

                        final fullName =
                            data?['name'] as String?;

                        final firstName =
                            _firstName(fullName);

                        return Text(
                          firstName.isEmpty
                              ? 'Good Morning'
                              : 'Good Morning, $firstName',
                          style: WhyNotTextStyles.serif(
                            size: 27,
                          ),
                        );
                      },
                    )
                  else
                    Text(
                      'Good Morning',
                      style: WhyNotTextStyles.serif(
                        size: 27,
                      ),
                    ),

                  const SizedBox(height: 6),

                  Text(
                    'What are we saving today?',
                    style: WhyNotTextStyles.muted(
                      size: 13,
                    ),
                  ),

                  // Search bar removed.

                  const SizedBox(height: 38),

                  Padding(
                    padding: const EdgeInsets.only(
                      right: 18,
                    ),
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

                  // ------------------------------------
                  // FUTURE FEATURE: NEARBY RECOMMENDATION
                  // ------------------------------------

                  Text(
                    'Near you',
                    style: WhyNotTextStyles.muted(
                      size: 13,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Nearby recommendations',
                    style: WhyNotTextStyles.serif(
                      size: 23,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Products and stores near you will appear here.',
                    style: WhyNotTextStyles.muted(
                      size: 13,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Padding(
                    padding: EdgeInsets.only(
                      right: 30,
                    ),
                    child: RecommendationPlaceholder(),
                  ),

                  const SizedBox(height: 54),

                  // ------------------------------------
                  // FUTURE FEATURE: PERSONALIZED PICKS
                  // ------------------------------------

                  Text(
                    'Top picks for you',
                    style: WhyNotTextStyles.serif(
                      size: 23,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Personalized recommendations will appear here.',
                    style: WhyNotTextStyles.muted(
                      size: 13,
                    ),
                  ),

                  const SizedBox(height: 17),

                  const Padding(
                    padding: EdgeInsets.only(
                      right: 35,
                    ),
                    child: RecommendationPlaceholder(),
                  ),

                  const SizedBox(height: 17),

                  const Padding(
                    padding: EdgeInsets.only(
                      right: 35,
                    ),
                    child: RecommendationPlaceholder(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const AppBottomNavigation(
        selectedIndex: 0,
      ),
    );
  }
}