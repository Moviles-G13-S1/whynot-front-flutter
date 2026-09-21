import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

enum _ProductSort {
  none,
  lowToHigh,
  highToLow,
}

class WishlistDetailScreen extends StatefulWidget {
  const WishlistDetailScreen({super.key});

  @override
  State<WishlistDetailScreen> createState() =>
      _WishlistDetailScreenState();
}

class _WishlistDetailScreenState
    extends State<WishlistDetailScreen> {
  _ProductSort _sort = _ProductSort.none;
  bool _showOnlyUnpurchased = false;

  String _formatPrice(dynamic price) {
    if (price == null) return '';

    if (price is num) {
      if (price % 1 == 0) {
        return '\$${price.toInt()}';
      }

      return '\$${price.toStringAsFixed(2)}';
    }

    return '\$$price';
  }

  double _numericPrice(
    QueryDocumentSnapshot<Map<String, dynamic>> product,
  ) {
    final price = product.data()['price'];

    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(price?.toString() ?? '') ?? 0;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    var filteredProducts = [...products];

    // Show only products that have NOT been purchased.
    if (_showOnlyUnpurchased) {
      filteredProducts = filteredProducts.where((product) {
        final purchased =
            product.data()['purchased'] as bool? ?? false;

        return !purchased;
      }).toList();
    }

    // Sort by price.
    switch (_sort) {
      case _ProductSort.lowToHigh:
        filteredProducts.sort(
          (a, b) =>
              _numericPrice(a).compareTo(_numericPrice(b)),
        );
        break;

      case _ProductSort.highToLow:
        filteredProducts.sort(
          (a, b) =>
              _numericPrice(b).compareTo(_numericPrice(a)),
        );
        break;

      case _ProductSort.none:
        break;
    }

    return filteredProducts;
  }

  void _toggleLowToHigh() {
    setState(() {
      _sort = _sort == _ProductSort.lowToHigh
          ? _ProductSort.none
          : _ProductSort.lowToHigh;
    });
  }

  void _toggleHighToLow() {
    setState(() {
      _sort = _sort == _ProductSort.highToLow
          ? _ProductSort.none
          : _ProductSort.highToLow;
    });
  }

  void _toggleUnpurchased() {
    setState(() {
      _showOnlyUnpurchased = !_showOnlyUnpurchased;
    });
  }

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>?;

    final wishlistId =
        arguments?['wishlistId'] as String?;

    final categoryId =
        arguments?['categoryId'] as String?;

    final categoryName =
        arguments?['categoryName'] as String? ??
            'Wishlist Category';

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: wishlistId == null
            ? Center(
                child: Text(
                  'Wishlist not found.',
                  style: WhyNotTextStyles.muted(size: 14),
                ),
              )
            : StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where(
                      'wishlistId',
                      isEqualTo: wishlistId,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load products.',
                        style:
                            WhyNotTextStyles.muted(size: 14),
                      ),
                    );
                  }

                  final allProducts =
                      snapshot.data?.docs ?? [];

                  final visibleProducts =
                      _applyFilters(allProducts);

                  return SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      47,
                      0,
                      135,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 25,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style:
                                    WhyNotTextStyles.serif(
                                  size: 30,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Text(
                                    '${allProducts.length} items',
                                    style:
                                        WhyNotTextStyles.muted(
                                      size: 15,
                                    ),
                                  ),

                                  const Spacer(),

                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes
                                            .newProductManual,
                                        arguments: {
                                          'wishlistId':
                                              wishlistId,
                                          'categoryId':
                                              categoryId,
                                          'categoryName':
                                              categoryName,
                                        },
                                      );
                                    },
                                    style:
                                        TextButton.styleFrom(
                                      foregroundColor:
                                          WhyNotColors.muted,
                                      padding:
                                          EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.add,
                                      size: 18,
                                      color:
                                          WhyNotColors.muted,
                                    ),
                                    label: const Text(
                                      'Add item',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        _WishlistFilters(
                          sort: _sort,
                          showOnlyUnpurchased:
                              _showOnlyUnpurchased,
                          onLowToHigh:
                              _toggleLowToHigh,
                          onHighToLow:
                              _toggleHighToLow,
                          onUnpurchased:
                              _toggleUnpurchased,
                        ),

                        const SizedBox(height: 32),

                        if (allProducts.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 25,
                            ),
                            child: Center(
                              child: Text(
                                'No items in this wishlist yet.',
                                style:
                                    WhyNotTextStyles.muted(
                                  size: 14,
                                ),
                              ),
                            ),
                          )
                        else if (visibleProducts.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 25,
                            ),
                            child: Center(
                              child: Text(
                                'No items match these filters.',
                                style:
                                    WhyNotTextStyles.muted(
                                  size: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 25,
                            ),
                            child: LayoutBuilder(
                              builder: (
                                context,
                                constraints,
                              ) {
                                const spacing = 20.0;

                                final cardWidth =
                                    (constraints.maxWidth -
                                            spacing) /
                                        2;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: 30,
                                  children:
                                      visibleProducts.map(
                                    (product) {
                                      final data =
                                          product.data();

                                      final name =
                                          data['name']
                                                  as String? ??
                                              'Product';

                                      final brand =
                                          data['brand']
                                                  as String? ??
                                              '';

                                      final imageUrl =
                                          data['imageUrl']
                                              as String?;

                                      final price =
                                          _formatPrice(
                                        data['price'],
                                      );

                                      final purchased =
                                          data['purchased']
                                                  as bool? ??
                                              false;

                                      return SizedBox(
                                        width: cardWidth,
                                        child:
                                            _WishlistProductCard(
                                          productId:
                                              product.id,
                                          name: name,
                                          brand: brand,
                                          price: price,
                                          imageUrl:
                                              imageUrl,
                                          purchased:
                                              purchased,
                                        ),
                                      );
                                    },
                                  ).toList(),
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
      bottomNavigationBar:
          const AppBottomNavigation(
        selectedIndex: 1,
      ),
    );
  }
}

class _WishlistFilters extends StatelessWidget {
  const _WishlistFilters({
    required this.sort,
    required this.showOnlyUnpurchased,
    required this.onLowToHigh,
    required this.onHighToLow,
    required this.onUnpurchased,
  });

  final _ProductSort sort;
  final bool showOnlyUnpurchased;

  final VoidCallback onLowToHigh;
  final VoidCallback onHighToLow;
  final VoidCallback onUnpurchased;

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
              selected:
                  sort == _ProductSort.lowToHigh,
              onTap: onLowToHigh,
            ),
          ),
          Expanded(
            child: _FilterItem(
              icon: Icons.arrow_downward,
              label: 'High to low',
              selected:
                  sort == _ProductSort.highToLow,
              onTap: onHighToLow,
            ),
          ),
          Expanded(
            child: _FilterItem(
              icon: Icons.shopping_bag_outlined,
              label: 'Unpurchased',
              selected: showOnlyUnpurchased,
              onTap: onUnpurchased,
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.black
                  : WhyNotColors.muted,
            ),

            const SizedBox(width: 5),

            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight.w500
                      : FontWeight.w300,
                  color: selected
                      ? Colors.black
                      : WhyNotColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
    required this.purchased,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String brand;
  final String price;
  final bool purchased;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        imageUrl != null &&
        imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: {
            'productId': productId,
            'sourceTab': 1,
          },
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 0.68,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(18),
                  child: hasImage
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Container(
                              color:
                                  WhyNotColors.card,
                              child:
                                  const Center(
                                child: Icon(
                                  Icons
                                      .image_not_supported_outlined,
                                  color:
                                      WhyNotColors.muted,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: WhyNotColors.card,
                        ),
                ),
              ),

              if (purchased)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        Colors.white,
                    child: Icon(
                      Icons.check,
                      size: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Padding(
            padding:
                const EdgeInsets.only(left: 4),
            child: Text(
              name,
              style:
                  WhyNotTextStyles.serif(size: 20),
            ),
          ),

          if (brand.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding:
                  const EdgeInsets.only(left: 5),
              child: Text(
                brand,
                style:
                    WhyNotTextStyles.muted(size: 11),
              ),
            ),
          ],

          const SizedBox(height: 3),

          Padding(
            padding:
                const EdgeInsets.only(left: 5),
            child: Text(
              price,
              style:
                  WhyNotTextStyles.muted(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}