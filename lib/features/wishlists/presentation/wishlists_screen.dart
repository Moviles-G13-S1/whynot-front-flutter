import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/wishlist_card.dart';

class WishlistsScreen extends StatelessWidget {
  const WishlistsScreen({super.key});

  Future<Map<String, String>> _loadCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();

    return {
      for (final document in snapshot.docs)
        document.id: document.data()['name'] as String? ?? document.id,
    };
  }

  Future<int> _loadItemCount(String wishlistId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('wishlistId', isEqualTo: wishlistId)
        .get();

    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                'Every thing you want, all in one place.',
                style: WhyNotTextStyles.muted(size: 15),
              ),
              const SizedBox(height: 30),

              Expanded(
                child: user == null
                    ? Center(
                        child: Text(
                          'No user logged in.',
                          style: WhyNotTextStyles.muted(size: 14),
                        ),
                      )
                    : FutureBuilder<Map<String, String>>(
                        future: _loadCategories(),
                        builder: (context, categorySnapshot) {
                          if (categorySnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (categorySnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load categories.',
                                style: WhyNotTextStyles.muted(size: 14),
                              ),
                            );
                          }

                          final categories =
                              categorySnapshot.data ?? <String, String>{};

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('wishlists')
                                .where(
                                  'ownerId',
                                  isEqualTo: user.uid,
                                )
                                .snapshots(),
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

                              final wishlists =
                                  wishlistSnapshot.data?.docs ?? [];

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
                                  final wishlist = wishlists[index];
                                  final data = wishlist.data();

                                  final categoryId =
                                      data['categoryId'] as String? ?? '';

                                  final categoryName =
                                      categories[categoryId] ?? categoryId;

                                  final imageUrl =
                                      data['imageUrl'] as String?;

                                  return FutureBuilder<int>(
                                    future: _loadItemCount(wishlist.id),
                                    builder: (context, countSnapshot) {
                                      final itemCount =
                                          countSnapshot.data ?? 0;

                                      return WishlistCard(
                                        label: categoryName,
                                        itemCount: itemCount,
                                        imageUrl: imageUrl,
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.wishlistDetail,
                                            arguments: {
                                              'wishlistId': wishlist.id,
                                              'categoryId': categoryId,
                                              'categoryName': categoryName,
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
                          );
                        },
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
      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 1,
      ),
    );
  }
}