import 'package:flutter/material.dart';

import '../../../../app/whynot_theme.dart';
import '../../../../shared/widgets/wishlist_card.dart';
import '../../../../app/app_routes.dart';


/// Search control used at the top of the home feed.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: WhyNotTextStyles.muted(size: 14),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: const Icon(Icons.mic_none_rounded, size: 21),
          filled: true,
          fillColor: WhyNotColors.search,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

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

/// Horizontally scrolling preview of the user's wishlist categories.
class WishlistRail extends StatelessWidget {
  const WishlistRail({super.key});

  static const _categories = ['Beauty', 'Clothes', 'Tech'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 18),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 17),
        itemBuilder: (context, index) => SizedBox(
          width: 131,
          child: WishlistCard(
            label: _categories[index],
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.wishlistDetail,
                arguments: {
                  'categoryName': _categories[index],
                  'itemCount': 6,
                },
              );
            },
            contentAlignment: CrossAxisAlignment.center,
          ),
        ),
      ),
    );
  }
}


/// Product placeholder and price used by recommendation sections.
class ProductRecommendation extends StatelessWidget {
  const ProductRecommendation({
    this.name = 'Product name',
    this.store = 'Product Store',
    this.originalPrice = r'$100',
    this.currentPrice = r'$50',
    super.key,
  });

  final String name;
  final String store;
  final String originalPrice;
  final String currentPrice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: {
            'name': name,
            'store': store,
            'originalPrice': originalPrice,
            'currentPrice': currentPrice,
            'sourceTab': 0,
          },
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 121,
            decoration: BoxDecoration(
              color: WhyNotColors.card,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              currentPrice,
              style: WhyNotTextStyles.muted(size: 13),
            ),
          ),
        ],
      ),
    );
  }
}
