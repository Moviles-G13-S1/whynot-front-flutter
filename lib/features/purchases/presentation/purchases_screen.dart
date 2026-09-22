import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../products/domain/product.dart';

enum _PurchaseSort { none, lowToHigh, highToLow }

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  _PurchaseSort _sort = _PurchaseSort.none;

  String _formatPrice(double price) =>
      price % 1 == 0 ? '\$${price.toInt()}' : '\$${price.toStringAsFixed(2)}';

  double _numericPrice(Product product) => product.price;

  List<Product> _sortProducts(List<Product> products) {
    final sortedProducts = [...products];

    switch (_sort) {
      case _PurchaseSort.lowToHigh:
        sortedProducts.sort(
          (a, b) => _numericPrice(a).compareTo(_numericPrice(b)),
        );
        break;

      case _PurchaseSort.highToLow:
        sortedProducts.sort(
          (a, b) => _numericPrice(b).compareTo(_numericPrice(a)),
        );
        break;

      case _PurchaseSort.none:
        break;
    }

    return sortedProducts;
  }

  void _toggleLowToHigh() {
    setState(() {
      _sort = _sort == _PurchaseSort.lowToHigh
          ? _PurchaseSort.none
          : _PurchaseSort.lowToHigh;
    });
  }

  void _toggleHighToLow() {
    setState(() {
      _sort = _sort == _PurchaseSort.highToLow
          ? _PurchaseSort.none
          : _PurchaseSort.highToLow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productController = context.dependencies.productController;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: productController.currentUserId == null
            ? Center(
                child: Text(
                  'No user logged in.',
                  style: WhyNotTextStyles.muted(size: 14),
                ),
              )
            : StreamBuilder<List<Product>>(
                stream: productController.watchCurrentProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load purchases.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    );
                  }

                  final allProducts = snapshot.data ?? const [];

                  final purchasedProducts = allProducts.where((product) {
                    return product.purchased;
                  }).toList();

                  final visibleProducts = _sortProducts(purchasedProducts);

                  return SingleChildScrollView(
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
                                'Purchases',
                                style: WhyNotTextStyles.serif(size: 30),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${purchasedProducts.length} items',
                                style: WhyNotTextStyles.muted(size: 15),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        _PurchaseFilters(
                          sort: _sort,
                          onLowToHigh: _toggleLowToHigh,
                          onHighToLow: _toggleHighToLow,
                        ),

                        const SizedBox(height: 32),

                        if (purchasedProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Center(
                              child: Text(
                                'You have no purchased items yet.',
                                style: WhyNotTextStyles.muted(size: 14),
                              ),
                            ),
                          )
                        else
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
                                  children: visibleProducts.map((product) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: _PurchaseCard(
                                        productId: product.id,
                                        name: product.name.isEmpty
                                            ? 'Product'
                                            : product.name,
                                        brand: product.brand,
                                        price: _formatPrice(product.price),
                                        imageUrl: product.imageUrl,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 3),
    );
  }
}

class _PurchaseFilters extends StatelessWidget {
  const _PurchaseFilters({
    required this.sort,
    required this.onLowToHigh,
    required this.onHighToLow,
  });

  final _PurchaseSort sort;
  final VoidCallback onLowToHigh;
  final VoidCallback onHighToLow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      width: double.infinity,
      color: WhyNotColors.search,
      child: Row(
        children: [
          Expanded(
            child: _FilterItem(
              icon: Icons.arrow_upward,
              label: 'Low to high',
              selected: sort == _PurchaseSort.lowToHigh,
              onTap: onLowToHigh,
            ),
          ),
          Expanded(
            child: _FilterItem(
              icon: Icons.arrow_downward,
              label: 'High to low',
              selected: sort == _PurchaseSort.highToLow,
              onTap: onHighToLow,
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
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 55,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.black : WhyNotColors.muted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                color: selected ? Colors.black : WhyNotColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String brand;
  final String price;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: {
            'productId': productId,

            // Keeps Purchases selected in bottom navigation.
            'sourceTab': 3,
          },
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.68,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: WhyNotColors.card,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: WhyNotColors.muted,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(color: WhyNotColors.card),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(name, style: WhyNotTextStyles.serif(size: 20)),
          ),

          if (brand.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(brand, style: WhyNotTextStyles.muted(size: 11)),
            ),
          ],

          const SizedBox(height: 3),

          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text(price, style: WhyNotTextStyles.muted(size: 12)),
          ),
        ],
      ),
    );
  }
}
