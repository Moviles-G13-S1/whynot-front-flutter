import 'package:flutter/material.dart';

import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/wishlist_card.dart';
import '../../../app/app_routes.dart';


class WishlistsScreen extends StatelessWidget {
  const WishlistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text(
                'My Wishlists',
                style: WhyNotTextStyles.serif(size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                'Every Thing you want, all in one place.',
                style: WhyNotTextStyles.muted(size: 15),
              ),
              const SizedBox(height: 30),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.62,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    WishlistCard(
                      label: 'Beauty',
                      itemCount: 6,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.wishlistDetail,
                          arguments: {
                            'categoryName': 'Beauty',
                            'itemCount': 6,
                          },
                        );
  },
                    ),
                    WishlistCard(
                      label: 'Clothes',
                      itemCount: 6,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.wishlistDetail,
                          arguments: {
                            'categoryName': 'Clothes',
                            'itemCount': 6,
                          },
                        );
                      },

                    ),
                    WishlistCard(
                      label: 'Tech',
                      itemCount: 6,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.wishlistDetail,
                          arguments: {
                            'categoryName': 'Tech',
                            'itemCount': 6,
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              Align(
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
      bottomNavigationBar:const AppBottomNavigation(
        selectedIndex: 1,
      ),
    );
  }
}
