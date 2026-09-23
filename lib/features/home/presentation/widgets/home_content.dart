import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/dependencies_scope.dart';
import '../../../../app/whynot_theme.dart';
import '../../../../shared/widgets/wishlist_card.dart';
import '../../../../shared/widgets/form_controls.dart';
import '../../../products/domain/product.dart';
import '../../../wishlists/domain/wishlist.dart';

/// Heading row with an optional action on its trailing edge.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
    super.key,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: WhyNotTextStyles.serif(size: 23))),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: WhyNotColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Horizontally scrolling preview of the current user's real wishlists.
class WishlistRail extends StatelessWidget {
  const WishlistRail({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlistController = context.dependencies.wishlistController;

    if (wishlistController.currentUserId == null) {
      return SizedBox(
        height: 230,
        child: Center(
          child: Text(
            'Log in to see your wishlists.',
            style: WhyNotTextStyles.muted(size: 13),
          ),
        ),
      );
    }

    return StreamBuilder<List<WishlistSummary>>(
      stream: wishlistController.watchCurrentSummaries(),
      builder: (context, wishlistSnapshot) {
        if (wishlistSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 230,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (wishlistSnapshot.hasError) {
          return SizedBox(
            height: 230,
            child: Center(
              child: Text(
                'Could not load wishlists.',
                style: WhyNotTextStyles.muted(size: 13),
              ),
            ),
          );
        }

        final wishlists = wishlistSnapshot.data ?? const [];

        if (wishlists.isEmpty) {
          return SizedBox(
            height: 230,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create your first wishlist.',
                    style: WhyNotTextStyles.muted(size: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 190,
                    child: PillButton(
                      label: 'Create a wishlist',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.newWishlist),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 18),
            itemCount: wishlists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 17),
            itemBuilder: (context, index) {
              final summary = wishlists[index];
              final wishlist = summary.wishlist;

              return SizedBox(
                width: 131,
                child: _HomeWishlistCard(
                  wishlistId: wishlist.id,
                  categoryId: wishlist.categoryId,
                  categoryName: summary.categoryName,
                  imageUrl: wishlist.imageUrl,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Wrapper around WishlistCard that keeps its item count synchronized
/// with Firestore.
class _HomeWishlistCard extends StatelessWidget {
  const _HomeWishlistCard({
    required this.wishlistId,
    required this.categoryName,
    this.categoryId,
    this.imageUrl,
  });

  final String wishlistId;
  final String? categoryId;
  final String categoryName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: context.dependencies.productController.watchByWishlist(
        wishlistId,
      ),
      builder: (context, snapshot) {
        final itemCount = snapshot.data?.length ?? 0;

        return WishlistCard(
          label: categoryName,
          itemCount: itemCount,
          imageUrl: imageUrl,
          contentAlignment: CrossAxisAlignment.center,
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.wishlistDetail,
              arguments: {
                'wishlistId': wishlistId,
                'categoryId': categoryId,
                'categoryName': categoryName,
                'itemCount': itemCount,
              },
            );
          },
        );
      },
    );
  }
}

/// Placeholder for recommendation features that will be implemented later.
class RecommendationPlaceholder extends StatelessWidget {
  const RecommendationPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 121,
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_outlined,
          size: 24,
          color: WhyNotColors.muted.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
