import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/brand_mark.dart';
import 'widgets/home_content.dart';

/// Main feed containing wishlists and product recommendations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  int _selectedNavigationIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Routes implemented destinations and keeps prototype destinations selected.
  void _onNavigationSelected(int index) {
    if (index == 2) return _showAddSheet();
    if (index == 4) {
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
      return;
    }
    setState(() => _selectedNavigationIndex = index);
  }

  /// Presents the temporary add-item action until its feature is implemented.
  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WhyNotColors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a new item', style: WhyNotTextStyles.serif(size: 26)),
              const SizedBox(height: 8),
              const Text(
                'Save something you love to one of your wishlists.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: WhyNotColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Text(
                    'Good Morning, Juliana',
                    style: WhyNotTextStyles.serif(size: 27),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'What are we saving today?',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: HomeSearchField(controller: _searchController),
                  ),
                  const SizedBox(height: 38),
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: HomeSectionHeader(
                      title: 'Your Wishlists',
                      action: 'View all',
                      onAction: () {},
                    ),
                  ),
                  const SizedBox(height: 29),
                  const WishlistRail(),
                  const SizedBox(height: 44),
                  Text('Near you', style: WhyNotTextStyles.muted(size: 13)),
                  const SizedBox(height: 20),
                  Text(
                    'You are close to a Zara',
                    style: WhyNotTextStyles.serif(size: 23),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Perfect moment to try the new item',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),
                  const SizedBox(height: 7),
                  const Padding(
                    padding: EdgeInsets.only(right: 30),
                    child: ProductRecommendation(),
                  ),
                  const SizedBox(height: 54),
                  Text(
                    'Top picks for you',
                    style: WhyNotTextStyles.serif(size: 23),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.only(right: 35),
                    child: ProductRecommendation(),
                  ),
                  const SizedBox(height: 17),
                  const Padding(
                    padding: EdgeInsets.only(right: 35),
                    child: ProductRecommendation(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedNavigationIndex,
        onSelected: _onNavigationSelected,
      ),
    );
  }
}
