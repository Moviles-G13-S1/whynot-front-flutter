import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/recommendation_controller.dart';
import '../../controllers/connectivity_status.dart';
import '../../models/recommendation_catalog_item.dart';
import '../../models/repositories/recommendation_repository.dart';
import '../widgets/connectivity_message.dart';

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
  Future<
    ({List<RecommendationCatalogItem> items, bool fromCache, Object? error})
  >?
  _load;
  String? _openingId;
  RecommendationController? _controller;
  StreamSubscription<String>? _invalidationSubscription;
  NetworkStatus _network = NetworkStatus.unknown;
  bool _checkingConnection = false;

  Future<
    ({List<RecommendationCatalogItem> items, bool fromCache, Object? error})
  >
  _request(
    RecommendationController controller, {
    bool forceRefresh = false,
    bool checkConnection = false,
  }) async {
    try {
      final result = await controller.getCatalog(
        forceRefresh: forceRefresh,
        checkConnection: checkConnection,
      );
      return (items: result.items, fromCache: result.fromCache, error: null);
    } catch (error) {
      return (
        items: const <RecommendationCatalogItem>[],
        fromCache: false,
        error: error,
      );
    }
  }

  void _networkChanged() {
    final status = _controller?.connectivity.status ?? NetworkStatus.unknown;
    if (status == _network) return;
    final wasOffline = _network == NetworkStatus.offline;
    setState(() {
      _network = status;
      if (wasOffline &&
          status == NetworkStatus.available &&
          !_checkingConnection) {
        _load = _request(_controller!, forceRefresh: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.dependencies.recommendationController;
    if (_controller != controller) {
      _invalidationSubscription?.cancel();
      _controller?.connectivity.removeListener(_networkChanged);
      _controller = controller;
      _network = controller.connectivity.status;
      controller.connectivity.addListener(_networkChanged);
      _load = _request(controller);
      _invalidationSubscription = controller.invalidations.listen((userId) {
        if (!mounted ||
            userId != context.dependencies.authController.currentUser?.id) {
          return;
        }
        setState(() {
          _load = _request(controller);
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

  void _refresh() {
    if (_controller?.connectivity.isOffline == true) return;
    setState(() {
      _load = _request(
        context.dependencies.recommendationController,
        forceRefresh: true,
      );
    });
  }

  void _checkConnection() {
    if (_checkingConnection) return;
    _checkingConnection = true;
    final request = _request(
      context.dependencies.recommendationController,
      forceRefresh: true,
      checkConnection: true,
    );
    setState(() {
      _load = request;
    });
    request.whenComplete(() => _checkingConnection = false);
  }

  Future<void> _open(RecommendationCatalogItem item) async {
    if (_openingId != null) return;
    setState(() => _openingId = item.sourceProductId);
    try {
      // Show the product immediately; only saving waits for the fresh event.
      final opening = context.dependencies.recommendationController
          .beginCatalogOpen(item);
      await Navigator.pushNamed(
        context,
        AppRoutes.recommendationDetail,
        arguments: opening,
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
            onPressed: _controller?.connectivity.isOffline == true
                ? null
                : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<({List<RecommendationCatalogItem> items, bool fromCache, Object? error})>(
        future: _load,
        builder: (context, snapshot) {
          final offline = _controller?.connectivity.isOffline == true;
          final previous = _controller?.staleCatalog;
          if (snapshot.connectionState != ConnectionState.done &&
              previous == null &&
              !offline) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.data?.error;
          if (error != null && previous == null && !offline) {
            final unavailable = error is RecommendationCatalogUnavailable;
            return ConnectivityEmptyState(
              label: 'Could not refresh',
              title: unavailable
                  ? 'Your picks are on pause'
                  : 'Picks are taking a moment',
              message: unavailable
                  ? 'Recommendations are unavailable in this app environment right now.'
                  : 'We couldn’t load your picks just now. Give it another try.',
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }
          if (offline && previous == null) {
            return ConnectivityEmptyState(
              label: 'Offline',
              title: 'Your picks will be here',
              message:
                  'Connect to discover new picks. We’ll load them when you’re back online.',
              icon: Icons.wifi_off_rounded,
              actionLabel: 'Check connection',
              onAction: _checkConnection,
            );
          }
          final usePrevious =
              previous != null &&
              (offline ||
                  error != null ||
                  snapshot.connectionState != ConnectionState.done);
          final result = usePrevious
              ? (items: previous, fromCache: true, error: null)
              : snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              if (usePrevious) ...[
                ConnectivityNotice(
                  label: offline ? 'Offline · outdated' : 'May be outdated',
                  title: 'Showing your last picks',
                  message: offline
                      ? 'These picks may have changed. We’ll look for new ones when you reconnect.'
                      : error != null
                      ? 'We couldn’t refresh just now. Your last picks are still here.'
                      : 'Checking for new picks while you browse.',
                  icon: offline
                      ? Icons.wifi_off_rounded
                      : Icons.history_rounded,
                  actionLabel: offline
                      ? 'Check connection'
                      : error != null
                      ? 'Try again'
                      : null,
                  onAction: offline
                      ? _checkConnection
                      : error != null
                      ? _refresh
                      : null,
                ),
                const SizedBox(height: 18),
              ] else ...[
                Text(
                  result.fromCache
                      ? 'Recently loaded picks'
                      : 'Fresh picks for you',
                  key: const Key('catalog-cache-status'),
                  style: WhyNotTextStyles.muted(size: 13),
                ),
                if (result.fromCache) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Loaded during your recent visit. These picks may have changed.',
                    style: WhyNotTextStyles.muted(size: 11),
                  ),
                ],
              ],
              const SizedBox(height: 6),
              Text(
                'Small dots mark details you’ve opened recently.',
                style: WhyNotTextStyles.muted(size: 11),
              ),
              const SizedBox(height: 8),
              Text(
                'Inspired by your favorite categories and people with similar tastes.',
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
