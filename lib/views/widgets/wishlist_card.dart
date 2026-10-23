import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';

/// Reusable wishlist card used across the application.
class WishlistCard extends StatelessWidget {
  const WishlistCard({
    required this.label,
    required this.onTap,
    this.itemCount,
    this.imageUrl,
    this.emoji,
    this.contentAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final String label;
  final int? itemCount;
  final String? imageUrl;
  final String? emoji;
  final VoidCallback onTap;
  final CrossAxisAlignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: contentAlignment,
        children: [
          AspectRatio(
            aspectRatio: 131 / 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: emoji != null
                  ? Container(
                      color: WhyNotColors.card,
                      child: Center(
                        child: Text(
                          emoji!,
                          style: const TextStyle(fontSize: 58),
                        ),
                      ),
                    )
                  : hasImage
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
          Text(label, style: WhyNotTextStyles.serif(size: 17)),
          if (itemCount != null) ...[
            const SizedBox(height: 5),
            Text('$itemCount items', style: WhyNotTextStyles.muted(size: 12)),
          ],
        ],
      ),
    );
  }
}
