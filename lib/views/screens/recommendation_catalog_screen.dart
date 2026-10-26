import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/recommendation_controller.dart';
import '../../models/recommendation_catalog_item.dart';
import '../../models/repositories/recommendation_repository.dart';
import '../widgets/form_controls.dart';

/// Browse a short-lived catalog snapshot and show which opened products occupy
/// the separate five-slot detail LRU.
class RecommendationCatalogScreen extends StatefulWidget {
  const RecommendationCatalogScreen({super.key});

  @override
  State<RecommendationCatalogScreen> createState() =>
      _RecommendationCatalogScreenState();
}

class _RecommendationCatalogScreenState
    extends State<RecommendationCatalogScreen> {
  Future<({List<RecommendationCatalogItem> items, bool fromCache})>? _load;
  String? _openingId;
  RecommendationController? _controller;
  StreamSubscription<String>? _invalidationSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.dependencies.recommendationController;
    if (_controller != controller) {
      _invalidationSubscription?.cancel();
      _controller = controller;
      _load = controller.getCatalog();
      _invalidationSubscription = controller.invalidations.listen((userId) {
        if (!mounted ||
            userId != context.dependencies.authController.currentUser?.id) {
          return;
        }
        setState(() {
          _load = controller.getCatalog();
        });
      });
    }
  }

  @override
  void dispose() {
    _invalidationSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _load = context.dependencies.recommendationController.getCatalog(
        forceRefresh: true,
      );
    });
  }

  Future<void> _open(RecommendationCatalogItem item) async {
    if (_openingId != null) return;
    setState(() => _openingId = item.sourceProductId);
    try {
      // Santiago Casasbuenas: Selecting an item rechecks eligibility and
      // creates the save event; simply listing cached rows creates no events.
      final recommendation = await context.dependencies.recommendationController
          .openCatalogItem(item.sourceProductId);
      if (!mounted) return;
      setState(() {});
      await Navigator.pushNamed(
        context,
        AppRoutes.recommendationDetail,
        arguments: recommendation,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This recommendation is unavailable. Refresh and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      appBar: AppBar(
        backgroundColor: WhyNotColors.background,
        title: Text('For you', style: WhyNotTextStyles.serif(size: 28)),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<({List<RecommendationCatalogItem> items, bool fromCache})>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final unavailable =
                snapshot.error is RecommendationCatalogUnavailable;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    unavailable
                        ? 'Recommendation catalog is not available in this app environment yet.'
                        : 'Could not load recommendations. Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  PillButton(label: 'Try again', onPressed: _refresh),
                ],
              ),
            );
          }
          final result = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              Text(
                result.fromCache
                    ? 'Catalog loaded from cache · no catalog request'
                    : 'Fetched fresh catalog',
                key: const Key('catalog-cache-status'),
                style: WhyNotTextStyles.muted(size: 13),
              ),
              if (result.fromCache) ...[
                const SizedBox(height: 6),
                Text(
                  'Cached results may be up to 5 minutes old.',
                  style: WhyNotTextStyles.muted(size: 11),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Gray dot = opened product details cached',
                style: WhyNotTextStyles.muted(size: 11),
              ),
              const SizedBox(height: 8),
              Text(
                'Products in your preferred category and categories you save, from people with similar profiles.',
                style: WhyNotTextStyles.muted(size: 13),
              ),
              const SizedBox(height: 22),
              if (result.items.isEmpty)
                const Text('No new recommendations yet. Try again later.'),
              for (final item in result.items) ...[
                _CatalogCard(
                  item: item,
                  cached: context.dependencies.recommendationController
                      .isCatalogProductCached(item.sourceProductId),
                  opening: _openingId == item.sourceProductId,
                  onTap: () => _open(item),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.item,
    required this.cached,
    required this.opening,
    required this.onTap,
  });

  final RecommendationCatalogItem item;
  final bool cached;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WhyNotColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    height: 78,
                    child: item.imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined)
                        : Image.network(
                            item.imageUrl,
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
                          item.name,
                          style: WhyNotTextStyles.serif(size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.brand,
                          style: WhyNotTextStyles.muted(size: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.categoryId,
                          style: WhyNotTextStyles.muted(size: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.reason,
                          style: WhyNotTextStyles.muted(size: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'COP ${item.price.round()}',
                          style: WhyNotTextStyles.muted(size: 13),
                        ),
                      ],
                    ),
                  ),
                  if (opening)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
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
                    key: Key('catalog-cached-dot-${item.sourceProductId}'),
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
