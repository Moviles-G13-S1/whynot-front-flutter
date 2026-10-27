
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/product.dart';
import '../../models/wishlist.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/wishlist_card.dart';

class WishlistsScreen extends StatelessWidget {
  const WishlistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlistController = context.dependencies.wishlistController;
    final userId = wishlistController.currentUserId;

    return Scaffold(
      backgroundColor: WhyNotColors.background,

      // Keep content above the bottom navigation bar.
      extendBody: false,

      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<WishlistSummary>>(
          stream: userId == null
              ? null
              : wishlistController.watchCurrentSummaries(),
          builder: (context, wishlistSnapshot) {
            final wishlists =
                wishlistSnapshot.data ?? const <WishlistSummary>[];

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 47, 25, 30),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Wishlists',
                          style: WhyNotTextStyles.serif(size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Every thing you want, all in one place.',
                          style: WhyNotTextStyles.muted(size: 15),
                        ),
                      ],
                    ),
                  ),
                ),

                if (userId == null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'No user logged in.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    ),
                  )
                else if (wishlistSnapshot.connectionState ==
                    ConnectionState.waiting)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (wishlistSnapshot.hasError)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Could not load wishlists.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    ),
                  )
                else if (wishlists.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'You do not have any wishlists yet.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    sliver: SliverGrid.builder(
                      itemCount: wishlists.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.62,
                          ),
                      itemBuilder: (context, index) {
                        final summary = wishlists[index];
                        final wishlist = summary.wishlist;

                        return StreamBuilder<List<Product>>(
                          stream: context.dependencies.productController
                              .watchByWishlist(wishlist.id),
                          builder: (context, countSnapshot) {
                            final itemCount =
                                countSnapshot.data?.length ?? 0;

                            return WishlistCard(
                              label: summary.categoryName,
                              itemCount: itemCount,
                              imageUrl: wishlist.imageUrl,
                              emoji: wishlist.emoji,
                              onTap: () {
                                wishlistController.trackIntent(
                                  'open',
                                  wishlistId: wishlist.id,
                                  categoryId: wishlist.categoryId,
                                );

                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.wishlistDetail,
                                  arguments: {
                                    'wishlistId': wishlist.id,
                                    'categoryId': wishlist.categoryId,
                                    'categoryName': summary.categoryName,
                                    'itemCount': itemCount,
                                    'emoji': wishlist.emoji,
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                // Juliana - Sprint 3:
                // New Wishlist appears directly below the final row,
                // aligned to the RIGHT, as in the original design.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 12, 25, 40),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.newWishlist,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: WhyNotColors.muted,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'New Wishlist',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 1,
      ),
    );
  }
}
