import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

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

  Future<void> _togglePurchased(
    BuildContext context,
    String productId,
    bool purchased,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
        'purchased': !purchased,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update product.'),
        ),
      );
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    String productId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: const Text(
            'This item will be permanently removed from your wishlist.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();

      if (!context.mounted) return;

      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete product.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final productId = arguments?['productId'] as String?;
    final sourceTab = arguments?['sourceTab'] as int? ?? 1;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: productId == null
            ? Center(
                child: Text(
                  'Product not found.',
                  style: WhyNotTextStyles.muted(size: 14),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load product.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                      child: Text(
                        'Product not found.',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                    );
                  }

                  final data = snapshot.data!.data()!;

                  final name =
                      data['name'] as String? ?? 'Product';

                  final brand =
                      data['brand'] as String? ?? '';

                  final imageUrl =
                      data['imageUrl'] as String?;

                  final productUrl =
                      data['productUrl'] as String?;

                  final purchased =
                      data['purchased'] as bool? ?? false;

                  final price =
                      _formatPrice(data['price']);

                  final hasImage =
                      imageUrl != null &&
                      imageUrl.trim().isNotEmpty;

                  final hasProductUrl =
                      productUrl != null &&
                      productUrl.trim().isNotEmpty;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      32,
                      47,
                      32,
                      135,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name
                        Text(
                          name,
                          style: WhyNotTextStyles.serif(
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Brand + Purchased on the same level
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                brand,
                                style: WhyNotTextStyles.muted(
                                  size: 15,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _togglePurchased(
                                  context,
                                  productId,
                                  purchased,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: purchased
                                    ? Colors.black
                                    : WhyNotColors.muted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                purchased
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: purchased
                                    ? Colors.black
                                    : WhyNotColors.muted,
                              ),
                              label: Text(
                                purchased
                                    ? 'Purchased'
                                    : 'Mark as purchased',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Product image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: double.infinity,
                            height: 360,
                            child: hasImage
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        color: WhyNotColors.card,
                                        child: const Center(
                                          child: Icon(
                                            Icons
                                                .image_not_supported_outlined,
                                            color:
                                                WhyNotColors.muted,
                                            size: 34,
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

                        const SizedBox(height: 20),

                        // Price + Edit
                        Row(
                          children: [
                            Text(
                              price,
                              style: WhyNotTextStyles.muted(
                                size: 15,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.editProduct,
                                  arguments: {
                                    'productId': productId,
                                    'sourceTab': sourceTab,
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    WhyNotColors.muted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: WhyNotColors.muted,
                              ),
                              label: const Text(
                                'Edit item',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Product URL
                        if (hasProductUrl) ...[
                          const SizedBox(height: 22),
                          Text(
                            'Product link',
                            style: WhyNotTextStyles.serif(
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            productUrl,
                            style: WhyNotTextStyles.muted(
                              size: 13,
                            ),
                          ),
                        ],

                        const SizedBox(height: 34),

                        const Divider(
                          color: WhyNotColors.divider,
                        ),

                        const SizedBox(height: 18),

                        // Delete
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              _deleteProduct(
                                context,
                                productId,
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Delete item',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: sourceTab,
      ),
    );
  }
}