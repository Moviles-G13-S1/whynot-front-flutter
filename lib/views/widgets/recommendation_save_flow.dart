import 'package:flutter/material.dart';

import '../../app/dependencies_scope.dart';
import '../../models/product_recommendation.dart';

const _createWishlistChoice = '__create_wishlist__';

/// Lets the user choose a compatible wishlist and saves the recommendation.
///
/// Returns `true` only when the recommendation was successfully saved. A
/// dismissed dialog returns `false` without showing an error.
Future<bool> saveRecommendationToWishlist(
  BuildContext context,
  ProductRecommendation recommendation,
) async {
  try {
    final wishlistController = context.dependencies.wishlistController;
    final recommendationController =
        context.dependencies.recommendationController;
    final summaries = await wishlistController.getCurrentSummaries();
    if (!context.mounted) return false;

    final matching = summaries
        .where(
          (summary) => summary.wishlist.categoryId == recommendation.categoryId,
        )
        .toList();
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save to wishlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matching.isEmpty)
              const Text('You need a wishlist in this category first.'),
            for (final summary in matching)
              ListTile(
                title: Text(summary.categoryName),
                onTap: () => Navigator.pop(dialogContext, summary.wishlist.id),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (matching.isEmpty)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _createWishlistChoice),
              child: const Text('Create wishlist and save'),
            ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return false;

    final wishlistId = choice == _createWishlistChoice
        ? await wishlistController.create(
            categoryId: recommendation.categoryId,
            imageUrl: '',
          )
        : choice;
    await recommendationController.saveRecommendation(
      recommendation: recommendation,
      wishlistId: wishlistId,
    );
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recommendation saved to your wishlist.')),
    );
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not save the recommendation. Please try again.'),
      ),
    );
    return false;
  }
}
