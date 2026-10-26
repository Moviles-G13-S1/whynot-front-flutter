import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import 'dart:math';

import '../../app/dependencies_scope.dart';
import '../../app/app_routes.dart';
import '../../app/whynot_theme.dart';
import '../../models/product_recommendation.dart';
import 'form_controls.dart';
import 'recommendation_save_flow.dart';

/// UI section responsible for displaying the personalized Smart Feature
/// recommendation.
///
/// This widget does not access Firebase or Cloud Functions directly.
/// Instead, it follows the application architecture:
///
/// SmartRecommendationSection
/// → RecommendationController
/// → RecommendationRepository
/// → FirebaseRecommendationRepository
/// → Firebase Cloud Functions
///
/// The backend returns at most one recommendation for the current user.
class SmartRecommendationSection extends StatefulWidget {
  const SmartRecommendationSection({super.key});

  @override
  State<SmartRecommendationSection> createState() =>
      _SmartRecommendationSectionState();
}

class _SmartRecommendationSectionState
    extends State<SmartRecommendationSection> {
  bool _isSaving = false;
  String? _savedEventId;
  String? _impressionId;
  String? _impressionRecommendationId;
  bool _displayed = false;
  bool _opened = false;

  String _newImpressionId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _record(String type, ProductRecommendation recommendation) {
    unawaited(
      context.dependencies.recommendationController
          .recordHomeCardEvent(
            impressionId: _impressionId!,
            recommendationEventId: recommendation.recommendationEventId,
            eventType: type,
          )
          .catchError((Object error) {
            // Firestore can queue offline writes. A rejected write must never block navigation.
            debugPrint('Home recommendation event delivery failed: $error');
          }),
    );
  }

  void _display(ProductRecommendation recommendation) {
    if (_impressionRecommendationId != recommendation.recommendationEventId) {
      _impressionRecommendationId = recommendation.recommendationEventId;
      _impressionId = _newImpressionId();
      _displayed = false;
      _opened = false;
    }
    if (_displayed || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _displayed = true;
    _record('card_displayed', recommendation);
  }

  /// Future containing the recommendation returned by the controller.
  ///
  /// It is stored in state so the Cloud Function is not called again every
  /// time the widget rebuilds.
  Future<ProductRecommendation?>? _recommendationFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // The controller is obtained through DependenciesScope instead of
    // accessing Firebase directly from the view.
    _recommendationFuture ??= context.dependencies.recommendationController
        .getRecommendation();
  }

  /// Requests the recommendation again after an error.
  ///
  /// Calling setState replaces the previous Future and causes the
  /// FutureBuilder to run through the loading/result states again.
  void _retry() {
    setState(() {
      _savedEventId = null;
      _impressionRecommendationId = null;
      _recommendationFuture = context.dependencies.recommendationController
          .getRecommendation();
    });
  }

  Future<void> _saveRecommendation(ProductRecommendation recommendation) async {
    if (_isSaving || _savedEventId == recommendation.recommendationEventId) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final saved = await saveRecommendationToWishlist(context, recommendation);
      if (!mounted) return;
      if (saved) {
        setState(() => _savedEventId = recommendation.recommendationEventId);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openDetails(ProductRecommendation recommendation) async {
    // A tap itself establishes visibility if the detector has not reported yet.
    _display(recommendation);
    if (!_displayed || _opened) return;
    _opened = true;
    _record('detail_opened', recommendation);
    await Navigator.pushNamed(
      context,
      AppRoutes.recommendationDetail,
      arguments: <String, Object?>{
        'recommendation': recommendation,
        'isSaved': _savedEventId == recommendation.recommendationEventId,
        'onSaved': () {
          if (!mounted) return;
          setState(() => _savedEventId = recommendation.recommendationEventId);
        },
      },
    );
    if (!mounted) return;
    // Returning from detail starts a new exposure only when the card is visible again.
    _impressionId = null;
    _impressionRecommendationId = null;
    _displayed = false;
    _opened = false;
    VisibilityDetectorController.instance.notifyNow();
  }

  /// Formats the numeric product price using Colombian-style thousands
  /// separators.
  ///
  /// Example:
  /// 250000 → $250.000
  String _formatPrice(num price) {
    final digits = price.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final positionFromEnd = digits.length - i;

      buffer.write(digits[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductRecommendation?>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        // The recommendation is currently being requested.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RecommendationLoadingCard();
        }

        // The repository/controller failed to obtain the recommendation.
        if (snapshot.hasError) {
          return _RecommendationErrorCard(onRetry: _retry);
        }

        final recommendation = snapshot.data;

        // A null recommendation is a valid backend response.
        //
        // This can happen when the most similar user does not have any
        // products that are new for the current user.
        if (recommendation == null) {
          return const _NoRecommendationCard();
        }

        // Successful Smart Feature response.
        return VisibilityDetector(
          key: ValueKey(
            'home-recommendation-${recommendation.recommendationEventId}',
          ),
          onVisibilityChanged: (info) {
            if (info.visibleFraction >= 0.5 && mounted) {
              _display(recommendation);
            }
          },
          child: _RecommendationCard(
            recommendation: recommendation,
            formattedPrice: _formatPrice(recommendation.price),
            isSaving: _isSaving,
            isSaved: _savedEventId == recommendation.recommendationEventId,
            onSave: () => _saveRecommendation(recommendation),
            onOpenDetails: () => _openDetails(recommendation),
          ),
        );
      },
    );
  }
}

/// Card used when a personalized recommendation was successfully returned.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.formattedPrice,
    required this.isSaving,
    required this.isSaved,
    required this.onSave,
    required this.onOpenDetails,
  });

  final ProductRecommendation recommendation;
  final String formattedPrice;
  final bool isSaving;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenDetails,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image returned by the recommendation backend.
                    _RecommendationImage(imageUrl: recommendation.imageUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recommended product name.
                            Text(
                              recommendation.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: WhyNotTextStyles.serif(size: 20),
                            ),

                            // Brand is optional in the visual layout.
                            if (recommendation.brand.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                recommendation.brand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: WhyNotTextStyles.muted(size: 12),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Product price.
                            Text(
                              formattedPrice,
                              style: WhyNotTextStyles.serif(size: 18),
                            ),

                            // Explanation generated by the recommendation backend.
                            if (recommendation.reason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                recommendation.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: WhyNotTextStyles.muted(size: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Center(
                  child: SizedBox(
                    width: 190,
                    child: PillButton(
                      label: isSaved
                          ? 'Saved'
                          : isSaving
                          ? 'Saving...'
                          : 'Save this product',
                      onPressed: isSaving || isSaved ? null : onSave,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the recommended product image.
///
/// If the backend does not provide an image URL, or the image cannot be
/// loaded, a neutral fallback is displayed instead.
class _RecommendationImage extends StatelessWidget {
  const _RecommendationImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 105,
        height: 125,
        child: imageUrl.trim().isEmpty
            ? const _ImageFallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ImageFallback();
                },
              ),
      ),
    );
  }
}

/// Fallback displayed when no valid product image is available.
class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhyNotColors.background,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: WhyNotColors.muted.withValues(alpha: 0.65),
        size: 28,
      ),
    );
  }
}

/// Loading state displayed while the Smart Feature request is running.
class _RecommendationLoadingCard extends StatelessWidget {
  const _RecommendationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 153,
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Empty state displayed when the backend returns no recommendation.
///
/// A null response is expected behavior and does not represent an error.
class _NoRecommendationCard extends StatelessWidget {
  const _NoRecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 121,
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 22,
            color: WhyNotColors.muted.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'No recommendation available yet.',
              textAlign: TextAlign.center,
              style: WhyNotTextStyles.muted(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state displayed when the recommendation request fails.
///
/// The retry action asks the controller for the recommendation again while
/// keeping Firebase-specific logic outside the view.
class _RecommendationErrorCard extends StatelessWidget {
  const _RecommendationErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 22,
            color: WhyNotColors.muted.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            'We could not load your recommendation.',
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.muted(size: 12),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: linkButtonStyle(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
