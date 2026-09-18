import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class WishlistDetailScreen extends StatelessWidget {
  const WishlistDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final categoryName =
        arguments?['categoryName'] as String? ?? 'Wishlist Category';

    final itemCount = arguments?['itemCount'] as int? ?? 3;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 47, 0, 135),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: WhyNotTextStyles.serif(size: 30),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$itemCount items',
                          style: WhyNotTextStyles.muted(size: 15),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: WhyNotColors.muted,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: WhyNotColors.muted,
                          ),
                          label: const Text(
                            'Add item',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const _WishlistFilters(),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 20.0;

                    final cardWidth =
                        (constraints.maxWidth - spacing) / 2;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: 30,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _WishlistProductCard(
                            name: 'Item name',
                            store: 'Product Store',
                            originalPrice: r'$100',
                            currentPrice: r'$50',
                            wishlist: categoryName,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _WishlistProductCard(
                            name: 'Item name',
                            store: 'Product Store',
                            originalPrice: r'$100',
                            currentPrice: r'$50',
                            wishlist: categoryName,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _WishlistProductCard(
                            name: 'Item name',
                            store: 'Product Store',
                            originalPrice: r'$100',
                            currentPrice: r'$50',
                            wishlist: categoryName,
                          ),
                        ),
                      ],
                    );
                  },
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

class _WishlistFilters extends StatelessWidget {
  const _WishlistFilters();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      width: double.infinity,
      color: WhyNotColors.search,
      child: const Row(
        children: [
          Expanded(
            child: _FilterItem(
              icon: Icons.filter_alt_outlined,
              label: 'Filter',
            ),
          ),
          Expanded(
            child: _FilterItem(
              icon: Icons.percent_rounded,
              label: 'Filter',
            ),
          ),
          Expanded(
            child: _FilterItem(
              icon: Icons.tune_rounded,
              label: 'Filter',
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: SizedBox(
        height: 55,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: WhyNotColors.muted,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: WhyNotTextStyles.muted(size: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({
    required this.name,
    required this.store,
    required this.originalPrice,
    required this.currentPrice,
    required this.wishlist,
  });

  final String name;
  final String store;
  final String originalPrice;
  final String currentPrice;
  final String wishlist;

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
            'wishlist': wishlist,
            'sourceTab': 1,
          },
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.68,
            child: Container(
              decoration: BoxDecoration(
                color: WhyNotColors.card,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              name,
              style: WhyNotTextStyles.serif(size: 20),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text(
              originalPrice,
              style: WhyNotTextStyles.muted(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}