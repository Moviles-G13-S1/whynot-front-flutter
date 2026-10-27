import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/recommendation_controller.dart';
import '../../controllers/connectivity_status.dart';
import '../../models/product_recommendation.dart';
import '../../models/catalog_product_details.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/form_controls.dart';
import '../widgets/recommendation_save_flow.dart';
import '../widgets/connectivity_message.dart';

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

  VoidCallback? _onSaved;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isSaved = false;
  ProductRecommendation? _catalogPreview;
  ProductRecommendation? _displayedRecommendation;
  String? _catalogSourceProductId;
  RecommendationController? _controller;
  NetworkStatus _network = NetworkStatus.unknown;

  void _networkChanged() {
    final status = _controller?.connectivity.status ?? NetworkStatus.unknown;
    if (_network == status) return;
    final wasOffline = _network == NetworkStatus.offline;
    setState(() {
      _network = status;
      if (status == NetworkStatus.offline &&
          _catalogPreview == null &&
          _displayedRecommendation != null) {
        _catalogPreview = CatalogProductDetails.fromRecommendation(
          _displayedRecommendation!,
        ).withEvent('');
      }
    });
    if (wasOffline &&
        status == NetworkStatus.available &&
        _catalogPreview != null) {
      _retry();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _controller = context.dependencies.recommendationController;
    _network = _controller!.connectivity.status;
    _controller!.connectivity.addListener(_networkChanged);

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is CatalogOpenRequest) {
      _catalogPreview = arguments.preview.withEvent('');
      _catalogSourceProductId = arguments.sourceProductId;
      _recommendationFuture = arguments.recommendation;
      return;
    }
    ProductRecommendation? recommendation;
    if (arguments is Map) {
      final candidate = arguments['recommendation'];
      if (candidate is ProductRecommendation) recommendation = candidate;
      if (arguments['stale'] == true && recommendation != null) {
        _catalogPreview = CatalogProductDetails.fromRecommendation(
          recommendation,
        ).withEvent('');
      }
      _isSaved = arguments['isSaved'] == true;
      final callback = arguments['onSaved'];
      if (callback is VoidCallback) _onSaved = callback;
    } else if (arguments is ProductRecommendation) {
      recommendation = arguments;
    }

    _displayedRecommendation = recommendation;

    _recommendationFuture = _resolve(
      _catalogPreview != null
          ? _controller!.getRecommendation(forceRefresh: true)
          : recommendation == null
          ? context.dependencies.recommendationController.getRecommendation()
          : Future<ProductRecommendation?>.value(recommendation),
    );
  }

  @override
  void dispose() {
    _controller?.connectivity.removeListener(_networkChanged);
    super.dispose();
  }

  void _retry() {
    if (_controller?.connectivity.isOffline == true) return;
    setState(() {
      final sourceProductId = _catalogSourceProductId;
      _recommendationFuture = _resolve(
        sourceProductId == null
            ? context.dependencies.recommendationController.getRecommendation(
                forceRefresh: true,
              )
            : context.dependencies.recommendationController.openCatalogItem(
                sourceProductId,
              ),
      );
    });
  }

  Future<void> _save(ProductRecommendation recommendation) async {
    if (_controller?.connectivity.isOffline == true) return;
    if (_isSaving || _isSaved || recommendation.recommendationEventId.isEmpty) {
      return;
    }
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
        child: FutureBuilder<RecommendationLoad>(
          future: _recommendationFuture,
          builder: (context, snapshot) {
            final preview = _catalogPreview;
            final offline = _controller?.connectivity.isOffline == true;
            final error = snapshot.data?.error;
            if (preview != null &&
                (offline ||
                    snapshot.connectionState == ConnectionState.waiting ||
                    error != null)) {
              return _RecommendationDetailContent(
                recommendation: preview,
                formattedPrice: _formatPrice(preview.price),
                categoryLabel: _categoryLabel(preview.categoryId),
                isSaving: false,
                isSaved: false,
                isPreparingSave:
                    snapshot.connectionState == ConnectionState.waiting,
                preparationFailed: error != null,
                offline: offline,
                onRetry: _retry,
                onSave: () {},
                onBack: _goBack,
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _RecommendationDetailLoading(onBack: _goBack);
            }
            if (error != null) {
              return _RecommendationDetailMessage(
                icon: Icons.cloud_off_outlined,
                title: offline
                    ? 'Your pick is waiting'
                    : 'Picks are taking a moment',
                message: offline
                    ? 'Connect to see your latest recommendation. We’ll check again when you’re online.'
                    : 'We couldn’t load your recommendation just now. Give it another try.',
                actionLabel: offline ? 'Try again when online' : 'Try again',
                onAction: offline ? null : _retry,
                onBack: _goBack,
              );
            }
            final recommendation = snapshot.data?.value;
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
            _displayedRecommendation = recommendation;
            return _RecommendationDetailContent(
              recommendation: recommendation,
              formattedPrice: _formatPrice(recommendation.price),
              categoryLabel: _categoryLabel(recommendation.categoryId),
              isSaving: _isSaving,
              isSaved: _isSaved,
              offline: offline,
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
    this.isPreparingSave = false,
    this.preparationFailed = false,
    this.offline = false,
    this.onRetry,
    required this.onSave,
    required this.onBack,
  });

  final ProductRecommendation recommendation;
  final String formattedPrice;
  final String categoryLabel;
  final bool isSaving;
  final bool isSaved;
  final bool isPreparingSave;
  final bool preparationFailed;
  final bool offline;
  final VoidCallback? onRetry;
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
              const SizedBox(height: 28),
              if (!isSaved && offline) ...[
                const ConnectivityNotice(
                  label: 'Offline',
                  title: 'Save it when you’re back',
                  message:
                      'Saving is unavailable offline. We’ll check this pick again when you reconnect.',
                  icon: Icons.wifi_off_rounded,
                ),
                const SizedBox(height: 18),
              ] else if (preparationFailed) ...[
                const ConnectivityNotice(
                  label: 'One more check',
                  title: 'Let’s confirm this pick',
                  message:
                      'We couldn’t confirm that it’s still available. Check again before saving.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 18),
              ],
              PillButton(
                height: 44,
                label: offline
                    ? 'Save when online'
                    : isPreparingSave
                    ? 'Checking availability...'
                    : preparationFailed
                    ? 'Check again'
                    : isSaved
                    ? 'Saved to wishlist'
                    : isSaving
                    ? 'Saving...'
                    : 'Save this product',
                onPressed: offline || isPreparingSave || isSaving || isSaved
                    ? null
                    : preparationFailed
                    ? onRetry
                    : onSave,
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
  final VoidCallback? onAction;
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
