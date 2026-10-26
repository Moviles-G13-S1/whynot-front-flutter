import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/product_recommendation.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/form_controls.dart';
import '../widgets/recommendation_save_flow.dart';

/// Full-page view for the user's current personalized recommendation.
///
/// A recommendation may be passed through route arguments to avoid requesting
/// it again after opening the Home card. Without arguments, the screen loads
/// the current recommendation and exposes loading, empty, and error states.
class RecommendationDetailScreen extends StatefulWidget {
  const RecommendationDetailScreen({super.key});

  @override
  State<RecommendationDetailScreen> createState() =>
      _RecommendationDetailScreenState();
}

class _RecommendationDetailScreenState
    extends State<RecommendationDetailScreen> {
  Future<ProductRecommendation?>? _recommendationFuture;
  VoidCallback? _onSaved;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    ProductRecommendation? recommendation;
    if (arguments is Map) {
      final candidate = arguments['recommendation'];
      if (candidate is ProductRecommendation) recommendation = candidate;
      _isSaved = arguments['isSaved'] == true;
      final callback = arguments['onSaved'];
      if (callback is VoidCallback) _onSaved = callback;
    } else if (arguments is ProductRecommendation) {
      recommendation = arguments;
    }

    _recommendationFuture = recommendation == null
        ? context.dependencies.recommendationController.getRecommendation()
        : Future<ProductRecommendation?>.value(recommendation);
  }

  void _retry() {
    setState(() {
      _recommendationFuture = context.dependencies.recommendationController
          .getRecommendation(forceRefresh: true);
    });
  }

  Future<void> _save(ProductRecommendation recommendation) async {
    if (_isSaving || _isSaved) return;
    setState(() => _isSaving = true);
    try {
      final saved = await saveRecommendationToWishlist(context, recommendation);
      if (!mounted || !saved) return;
      setState(() => _isSaved = true);
      _onSaved?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _goBack() async {
    if (await Navigator.maybePop(context)) return;
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  String _formatPrice(num price) {
    final digits = price.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final positionFromEnd = digits.length - index;
      buffer.write(digits[index]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write('.');
    }
    return '\$$buffer';
  }

  String _categoryLabel(String categoryId) {
    final words = categoryId
        .trim()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words
        .map(
          (word) =>
              '${word.substring(0, 1).toUpperCase()}'
              '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<ProductRecommendation?>(
          future: _recommendationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _RecommendationDetailLoading(onBack: _goBack);
            }
            if (snapshot.hasError) {
              return _RecommendationDetailMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load your recommendation',
                message: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: _retry,
                onBack: _goBack,
              );
            }
            final recommendation = snapshot.data;
            if (recommendation == null) {
              return _RecommendationDetailMessage(
                icon: Icons.auto_awesome_outlined,
                title: 'No recommendation yet',
                message:
                    'Keep adding products to your wishlists so we can learn '
                    'what you like.',
                actionLabel: 'Back to home',
                onAction: _goBack,
                onBack: _goBack,
              );
            }
            return _RecommendationDetailContent(
              recommendation: recommendation,
              formattedPrice: _formatPrice(recommendation.price),
              categoryLabel: _categoryLabel(recommendation.categoryId),
              isSaving: _isSaving,
              isSaved: _isSaved,
              onSave: () => _save(recommendation),
              onBack: _goBack,
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
    );
  }
}

class _RecommendationDetailContent extends StatelessWidget {
  const _RecommendationDetailContent({
    required this.recommendation,
    required this.formattedPrice,
    required this.categoryLabel,
    required this.isSaving,
    required this.isSaved,
    required this.onSave,
    required this.onBack,
  });

  final ProductRecommendation recommendation;
  final String formattedPrice;
  final String categoryLabel;
  final bool isSaving;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 132),
          sliver: SliverList.list(
            children: [
              _DetailHeader(onBack: onBack),
              const SizedBox(height: 27),
              _RecommendationHeroImage(imageUrl: recommendation.imageUrl),
              const SizedBox(height: 23),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: WhyNotColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        categoryLabel.isEmpty
                            ? 'Personalized pick'
                            : categoryLabel,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                recommendation.name,
                style: WhyNotTextStyles.serif(size: 30),
              ),
              if (recommendation.brand.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  recommendation.brand,
                  style: WhyNotTextStyles.muted(size: 14),
                ),
              ],
              const SizedBox(height: 18),
              Text(formattedPrice, style: WhyNotTextStyles.serif(size: 24)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: WhyNotColors.form,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_outlined, size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this pick?',
                            style: WhyNotTextStyles.serif(size: 19),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recommendation.reason.trim().isEmpty
                                ? 'This product matches your preferences and '
                                      'wishlist activity.'
                                : recommendation.reason,
                            style: WhyNotTextStyles.muted(size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (recommendation.productUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('Product link', style: WhyNotTextStyles.serif(size: 19)),
                const SizedBox(height: 8),
                SelectableText(
                  recommendation.productUrl,
                  style: WhyNotTextStyles.muted(size: 12),
                ),
              ],
              const SizedBox(height: 34),
              PillButton(
                height: 44,
                label: isSaved
                    ? 'Saved to wishlist'
                    : isSaving
                    ? 'Saving...'
                    : 'Save this product',
                onPressed: isSaving || isSaved ? null : onSave,
              ),
              if (isSaved) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'This recommendation is in your wishlist.',
                        textAlign: TextAlign.center,
                        style: WhyNotTextStyles.muted(size: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationHeroImage extends StatelessWidget {
  const _RecommendationHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: imageUrl.trim().isEmpty
            ? const _RecommendationImageFallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: WhyNotColors.card,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (_, _, _) => const _RecommendationImageFallback(),
              ),
      ),
    );
  }
}

class _RecommendationImageFallback extends StatelessWidget {
  const _RecommendationImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhyNotColors.card,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 42,
            color: WhyNotColors.muted.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 8),
          Text('Image unavailable', style: WhyNotTextStyles.muted(size: 11)),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        const Expanded(
          child: Text(
            'Recommendation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _RecommendationDetailLoading extends StatelessWidget {
  const _RecommendationDetailLoading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading recommendation',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHeader(onBack: onBack),
            const SizedBox(height: 27),
            const AspectRatio(
              aspectRatio: 1.2,
              child: _SkeletonBlock(radius: 22),
            ),
            const SizedBox(height: 24),
            const _SkeletonBlock(height: 18, width: 110),
            const SizedBox(height: 16),
            const _SkeletonBlock(height: 32),
            const SizedBox(height: 10),
            const _SkeletonBlock(height: 16, width: 150),
            const SizedBox(height: 28),
            const _SkeletonBlock(height: 116, radius: 18),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.height, this.width, this.radius = 8});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: WhyNotColors.card.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _RecommendationDetailMessage extends StatelessWidget {
  const _RecommendationDetailMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onBack,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 132),
      child: Column(
        children: [
          _DetailHeader(onBack: onBack),
          const Spacer(),
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: WhyNotColors.card,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 31, color: WhyNotColors.muted),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.serif(size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.muted(size: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 190,
            child: PillButton(label: actionLabel, onPressed: onAction),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
