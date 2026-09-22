import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../products/domain/product.dart';
import '../domain/wishlist.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/wishlist_card.dart';

class WishlistsScreen extends StatelessWidget {
  const WishlistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlistController = context.dependencies.wishlistController;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 47, 25, 115),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Wishlists', style: WhyNotTextStyles.serif(size: 30)),
              const SizedBox(height: 8),
              Text(
                'Every thing you want, all in one place.',
                style: WhyNotTextStyles.muted(size: 15),
              ),
              const SizedBox(height: 30),

              Expanded(
                child: wishlistController.currentUserId == null
                    ? Center(
                        child: Text(
                          'No user logged in.',
                          style: WhyNotTextStyles.muted(size: 14),
                        ),
                      )
                    : StreamBuilder<List<WishlistSummary>>(
                        stream: wishlistController.watchCurrentSummaries(),
                        builder: (context, wishlistSnapshot) {
                          if (wishlistSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (wishlistSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load wishlists.',
                                style: WhyNotTextStyles.muted(size: 14),
                              ),
                            );
                          }

                          final wishlists = wishlistSnapshot.data ?? const [];

                          if (wishlists.isEmpty) {
                            return Center(
                              child: Text(
                                'You do not have any wishlists yet.',
                                style: WhyNotTextStyles.muted(size: 14),
                              ),
                            );
                          }

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
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
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.wishlistDetail,
                                        arguments: {
                                          'wishlistId': wishlist.id,
                                          'categoryId': wishlist.categoryId,
                                          'categoryName': summary.categoryName,
                                          'itemCount': itemCount,
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.newWishlist);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: WhyNotColors.muted,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 1),
    );
  }
}
