import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';
import '../../models/store_summary.dart';

/// Santiago Casasbuenas: The store's logo on a rounded-square tile, falling
/// back to its initial.
///
/// Logos are disk-cached, so stores seen before keep their logo offline. A
/// store without a logo, or one not cached while offline, shows its initial.
class StoreLogo extends StatelessWidget {
  const StoreLogo({
    required this.domain,
    required this.name,
    this.size = 40,
    this.loadImage = true,
    super.key,
  });

  final String domain;
  final String name;
  final double size;

  /// Widget tests turn network images off.
  final bool loadImage;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: WhyNotTextStyles.serif(size: size * 0.45),
      ),
    );
    return Semantics(
      label: '$name logo',
      image: true,
      // A rounded square, like an app icon: square logos keep their corners
      // instead of being cut by a circle, and round ones sit on the tile.
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
          color: WhyNotColors.field,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: WhyNotColors.divider),
        ),
        child: !loadImage
            ? initial
            : ClipRRect(
                // Square logos get the same corner shape as the tile.
                borderRadius: BorderRadius.circular(size * 0.16),
                child: CachedNetworkImage(
                  imageUrl: storeLogoUrl(domain).toString(),
                  fit: BoxFit.contain,
                  // Santiago Casasbuenas: Sprint 4 micro-optimization. Decode
                  // the 128 px icon at the size it is drawn, not in full.
                  memCacheWidth: decodeWidthFor(
                    size * 0.72,
                    MediaQuery.devicePixelRatioOf(context),
                  ),
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => initial,
                  errorWidget: (_, _, _) => initial,
                ),
              ),
      ),
    );
  }
}

/// Physical pixels needed to draw an image [logicalWidth] wide, so it is
/// decoded no larger than it is shown.
int decodeWidthFor(double logicalWidth, double devicePixelRatio) =>
    (logicalWidth * devicePixelRatio).ceil();
