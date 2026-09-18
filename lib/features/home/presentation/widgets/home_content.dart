import 'package:flutter/material.dart';

import '../../../../app/whynot_theme.dart';

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
        separatorBuilder: (_, _) => const SizedBox(width: 17),
        itemBuilder: (context, index) =>
            _WishlistCard(label: _categories[index], onTap: () {}),
      ),
    );
  }
}

/// Placeholder card for one wishlist category.
class _WishlistCard extends StatelessWidget {
  const _WishlistCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 131,
        child: Column(
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: WhyNotColors.card,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 12),
            Text(label, style: WhyNotTextStyles.serif(size: 17)),
          ],
        ),
      ),
    );
  }
}

/// Product placeholder and price used by recommendation sections.
class ProductRecommendation extends StatelessWidget {
  const ProductRecommendation({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: Text(r'$50', style: WhyNotTextStyles.muted(size: 13)),
        ),
      ],
    );
  }
}
