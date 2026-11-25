import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/whynot_theme.dart';
import '../../models/store_summary.dart';
import '../widgets/store_logo.dart';
import 'stores_screen.dart';

/// Santiago Casasbuenas: Sprint 4. The saved products from one online store.
class StoreDetailScreen extends StatelessWidget {
  const StoreDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! StoreDetailArguments) {
      return Scaffold(
        backgroundColor: WhyNotColors.background,
        appBar: AppBar(backgroundColor: WhyNotColors.background),
        body: const Center(child: Text('This store is unavailable.')),
      );
    }
    final group = arguments.group;
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      appBar: AppBar(
        backgroundColor: WhyNotColors.background,
        title: Text(group.name, style: WhyNotTextStyles.serif(size: 28)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Row(
            children: [
              StoreLogo(domain: group.domain, name: group.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.domain, style: WhyNotTextStyles.muted(size: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${group.productCount} saved · '
                      '${formatStorePrice(group.pendingValue)} still to buy',
                      style: WhyNotTextStyles.muted(size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (arguments.mayBeOutdated) ...[
            const SizedBox(height: 4),
            Text(
              'Saved information. Details may be outdated.',
              style: WhyNotTextStyles.muted(size: 12),
            ),
          ],
          const SizedBox(height: 18),
          for (final product in group.products) ...[
            _StoreProductTile(
              key: ValueKey('store-product-${product.id}'),
              product: product,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StoreProductTile extends StatelessWidget {
  const _StoreProductTile({required this.product, super.key});

  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    final image = product.imageUrl.trim();
    const placeholder = ColoredBox(
      color: WhyNotColors.card,
      child: Center(
        child: Icon(Icons.shopping_bag_outlined, color: WhyNotColors.muted),
      ),
    );
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.productDetail,
        arguments: {'productId': product.id, 'sourceTab': 0},
      ),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              // Disk-cached thumbnails stay visible offline; failures show the
              // placeholder instead of a broken image.
              child: image.isEmpty
                  ? placeholder
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => placeholder,
                      errorWidget: (_, _, _) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.brand,
                  style: WhyNotTextStyles.muted(size: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatStorePrice(product.price)),
              if (product.purchased)
                Text('Purchased', style: WhyNotTextStyles.muted(size: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
