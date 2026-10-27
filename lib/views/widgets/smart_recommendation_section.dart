import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/dependencies_scope.dart';
import '../../app/app_routes.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/recommendation_controller.dart';
import '../../controllers/connectivity_status.dart';
import '../../models/product_recommendation.dart';
import 'form_controls.dart';
import 'recommendation_save_flow.dart';
import 'connectivity_message.dart';

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
  Future<RecommendationLoad>? _recommendationFuture;

  Future<RecommendationLoad> _resolve(
    Future<ProductRecommendation?> future,
  ) async {
    try {
      return (value: await future, error: null);
    } catch (error) {
      return (value: null, error: error);
    }
  }

  RecommendationController? _controller;
  StreamSubscription<String>? _invalidationSubscription;
  NetworkStatus _network = NetworkStatus.unknown;

  void _networkChanged() {
    final status = _controller?.connectivity.status ?? NetworkStatus.unknown;
    if (status == _network) return;
    final wasOffline = _network == NetworkStatus.offline;
    setState(() {
      _network = status;
      if (wasOffline && status == NetworkStatus.available) {
        _recommendationFuture = _resolve(
          _controller!.getRecommendation(forceRefresh: true),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // The controller is obtained through DependenciesScope instead of
    // accessing Firebase directly from the view.
    final controller = context.dependencies.recommendationController;
    if (_controller != controller) {
      _invalidationSubscription?.cancel();
      _controller?.connectivity.removeListener(_networkChanged);
      _controller = controller;
      _network = controller.connectivity.status;
      controller.connectivity.addListener(_networkChanged);
      _recommendationFuture = _resolve(controller.getRecommendation());
      _invalidationSubscription = controller.invalidations.listen((userId) {
        if (!mounted ||
            _isSaving ||
            userId != context.dependencies.authController.currentUser?.id) {
          return;
        }
        setState(() {
          _recommendationFuture = _resolve(controller.getRecommendation());
        });
      });
    }
  }

  @override
  void dispose() {
    _invalidationSubscription?.cancel();
    _controller?.connectivity.removeListener(_networkChanged);
    super.dispose();
  }

  /// Santiago Casasbuenas: Retry deliberately bypasses the result cache.
  ///
  /// Calling setState replaces the previous Future and causes the
  /// FutureBuilder to run through the loading/result states again.
  void _retry() {
    if (_controller?.connectivity.isOffline == true) return;
    setState(() {
      _savedEventId = null;
      _recommendationFuture = _resolve(
        context.dependencies.recommendationController.getRecommendation(
          forceRefresh: true,
        ),
      );
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

  Future<void> _openDetails(
    ProductRecommendation recommendation, {
    bool stale = false,
  }) async {
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
        'stale': stale,
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
    return FutureBuilder<RecommendationLoad>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        final offline = _controller?.connectivity.isOffline == true;
        final previous = _controller?.staleRecommendation;
        final error = snapshot.data?.error;
        if (previous != null &&
            (offline ||
                error != null ||
                snapshot.connectionState == ConnectionState.waiting)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConnectivityNotice(
                label: offline ? 'Offline · outdated' : 'May be outdated',
                title: 'Keeping your last pick',
                message: offline
                    ? 'This pick may have changed. We’ll look for a new one when you reconnect.'
                    : error != null
                    ? 'We couldn’t update your pick just now. You can try again.'
                    : 'Checking for a new pick while you browse.',
                icon: offline ? Icons.wifi_off_rounded : Icons.history_rounded,
                actionLabel: !offline && error != null ? 'Try again' : null,
                onAction: !offline && error != null ? _retry : null,
              ),
              const SizedBox(height: 12),
              VisibilityDetector(
                key: ValueKey(
                  'home-recommendation-${previous.recommendationEventId}',
                ),
                onVisibilityChanged: (info) {
                  if (info.visibleFraction >= 0.5 && mounted) {
                    _display(previous);
                  }
                },
                child: _RecommendationCard(
                  recommendation: previous,
                  formattedPrice: _formatPrice(previous.price),
                  isSaving: false,
                  isSaved: false,
                  onSave: () {},
                  onOpenDetails: () => _openDetails(previous, stale: true),
                  saveDisabled: true,
                  offline: offline,
                ),
              ),
            ],
          );
        }
        if (offline) return const _RecommendationOfflineCard();
        // The recommendation is currently being requested.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RecommendationLoadingCard();
        }

        // The repository/controller failed to obtain the recommendation.
        if (error != null) {
          return _RecommendationErrorCard(onRetry: _retry);
        }

        final recommendation = snapshot.data?.value;

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
    this.saveDisabled = false,
    this.offline = false,
  });

  final ProductRecommendation recommendation;
  final String formattedPrice;
  final bool isSaving;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onOpenDetails;
  final bool saveDisabled;
  final bool offline;

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
                          : saveDisabled && offline
                          ? 'Save when online'
                          : saveDisabled
                          ? 'Check before saving'
                          : 'Save this product',
                      onPressed: isSaving || isSaved || saveDisabled
                          ? null
                          : onSave,
                    ),
                  ),
                ),
                if (saveDisabled)
                  Text(
                    offline
                        ? 'Saving is unavailable offline.'
                        : 'Open this pick to check availability before saving.',
                    textAlign: TextAlign.center,
                    style: WhyNotTextStyles.muted(size: 11),
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

class _RecommendationOfflineCard extends StatelessWidget {
  const _RecommendationOfflineCard();

  @override
  Widget build(BuildContext context) => const ConnectivityNotice(
    label: 'Offline',
    title: 'Your next pick is waiting',
    message:
        'Connect to see a recommendation made for you. We’ll load it when you’re back online.',
    icon: Icons.wifi_off_rounded,
    backgroundColor: WhyNotColors.card,
  );
}

/// Error state displayed when the recommendation request fails.
///
/// The retry action asks the controller for the recommendation again while
/// keeping Firebase-specific logic outside the view.
class _RecommendationErrorCard extends StatelessWidget {
  const _RecommendationErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ConnectivityNotice(
    label: 'Could not refresh',
    title: 'Picks are taking a moment',
    message:
        'We couldn’t find your recommendation just now. Give it another try.',
    icon: Icons.cloud_off_outlined,
    actionLabel: 'Try again',
    onAction: onRetry,
    backgroundColor: WhyNotColors.card,
  );
}
