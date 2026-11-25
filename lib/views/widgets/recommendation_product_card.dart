import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';
import '../../models/catalog_product_details.dart';

/// The shared product card for the catalog and the local browsing history.
class RecommendationProductCard extends StatelessWidget {
  const RecommendationProductCard({
    required this.sourceProductId,
    required this.details,
    required this.cached,
    required this.onTap,
    super.key,
  });

  final String sourceProductId;
  final CatalogProductDetails details;
  final bool cached;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WhyNotColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    height: 78,
                    child: details.imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined)
                        : Image.network(
                            details.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details.name,
                          style: WhyNotTextStyles.serif(size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details.brand,
                          style: WhyNotTextStyles.muted(size: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          details.categoryId,
                          style: WhyNotTextStyles.muted(size: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details.reason,
                          style: WhyNotTextStyles.muted(size: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'COP ${details.price.round()}',
                          style: WhyNotTextStyles.muted(size: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (cached)
              Positioned(
                right: 9,
                bottom: 9,
                child: Semantics(
                  label: 'Product details cached',
                  child: Container(
                    key: Key('catalog-cached-dot-$sourceProductId'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
