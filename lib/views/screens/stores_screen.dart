import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/stores_controller.dart';
import '../../models/store_summary.dart';
import '../widgets/compact_connection_notice.dart';
import '../widgets/store_logo.dart';

/// Prices with thousands separators, as in "\$2.500.000".
String formatStorePrice(double price) {
  final whole = price.truncate().abs().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final cents = (price.abs() * 100).round() % 100;
  final sign = price < 0 ? '-' : '';
  return cents == 0
      ? '$sign\$$grouped'
      : '$sign\$$grouped,${cents.toString().padLeft(2, '0')}';
}

/// Arguments for [AppRoutes.storeDetail].
class StoreDetailArguments {
  const StoreDetailArguments({
    required this.group,
    required this.mayBeOutdated,
  });

  final StoreGroup group;
  final bool mayBeOutdated;
}

/// Santiago Casasbuenas: Sprint 4. The user's saved products grouped by the
/// online store their link points to.
class StoresScreen extends StatefulWidget {
  const StoresScreen({this.controller, this.loadLogos = true, super.key});

  /// Injected by tests; the screen otherwise owns its controller.
  final StoresController? controller;

  /// Widget tests turn network logos off.
  final bool loadLogos;

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  StoresController? _controller;
  bool _ownsController = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createController();
    _controller!.start();
  }

  StoresController _createController() {
    final dependencies = context.dependencies;
    return StoresController(
      watchProducts: dependencies.productController.watchCurrentProducts,
      currentUserId: () => dependencies.productController.currentUserId,
      connectivity: dependencies.connectivity,
      store: dependencies.storeSummaryStore,
    );
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WhyNotColors.background,
    appBar: AppBar(
      backgroundColor: WhyNotColors.background,
      title: Text('Your stores', style: WhyNotTextStyles.serif(size: 28)),
    ),
    body: AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller!.retry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: _content(_controller!),
        ),
      ),
    ),
  );

  List<Widget> _content(StoresController controller) {
    final summary = controller.summary;
    final notice = _notice(controller);
    if (summary == null) {
      if (controller.error != null) {
        return [
          ?notice,
          CompactConnectionNotice(
            title: 'Couldn’t load your stores',
            message: controller.isOffline
                ? 'Connect to Wi-Fi or mobile data to group your products.'
                : 'Something went wrong while loading your products.',
            icon: controller.isOffline
                ? Icons.wifi_off_rounded
                : Icons.error_outline_rounded,
            actionLabel: 'Try again',
            onAction: controller.retry,
          ),
        ];
      }
      return [
        ?notice,
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      ?notice,
      Text(
        'Products grouped by the store their link points to.',
        style: WhyNotTextStyles.muted(size: 13),
      ),
      const SizedBox(height: 18),
      _Overview(summary: summary),
      const SizedBox(height: 22),
      if (summary.groups.isEmpty)
        Text(
          summary.totalProducts == 0
              ? 'You haven’t saved any products yet.'
              : 'None of your products has a store link yet. Add one when '
                    'you edit a product to see it here.',
          style: WhyNotTextStyles.muted(size: 13),
        )
      else
        for (final group in summary.groups) ...[
          _StoreTile(
            key: ValueKey('store-${group.domain}'),
            group: group,
            loadLogos: widget.loadLogos,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.storeDetail,
              arguments: StoreDetailArguments(
                group: group,
                mayBeOutdated: controller.mayBeOutdated,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      if (summary.unattributed > 0) ...[
        const SizedBox(height: 12),
        Text(
          summary.unattributed == 1
              ? '1 product has no usable store link.'
              : '${summary.unattributed} products have no usable store link.',
          style: WhyNotTextStyles.muted(size: 12),
        ),
      ],
    ];
  }

  Widget? _notice(StoresController controller) {
    if (controller.hasPendingWrites) {
      return const CompactConnectionNotice(
        title: 'Your changes are still saving',
        message: 'Stores include them; they sync when you reconnect.',
        icon: Icons.cloud_upload_outlined,
      );
    }
    if (controller.isOffline) {
      return CompactConnectionNotice(
        title: 'You’re offline',
        message: controller.summary == null
            ? 'Your stores will appear when you reconnect.'
            : 'Showing your saved stores. They may be outdated.',
        icon: Icons.wifi_off_rounded,
        actionLabel: controller.summary == null ? null : 'Try again',
        onAction: controller.summary == null ? null : controller.retry,
      );
    }
    if (controller.mayBeOutdated) {
      return CompactConnectionNotice(
        title: 'Saved information',
        message: controller.source == StoresSource.device
            ? 'Showing the stores saved on this device while we update them.'
            : 'Updates resume when you reconnect to Wi-Fi or mobile data.',
        icon: Icons.history_rounded,
        actionLabel: controller.error != null ? 'Try again' : null,
        onAction: controller.error != null ? controller.retry : null,
      );
    }
    return null;
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});

  final StoreSummary summary;

  @override
  Widget build(BuildContext context) {
    final stores = summary.groups.length;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            value: '$stores',
            label: stores == 1 ? 'store' : 'stores',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            value: '${summary.linkedProducts}',
            label: 'of ${summary.totalProducts} products linked',
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: WhyNotColors.form,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: WhyNotTextStyles.serif(size: 26)),
        const SizedBox(height: 2),
        Text(
          label,
          style: WhyNotTextStyles.muted(size: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.group,
    required this.onTap,
    required this.loadLogos,
    super.key,
  });

  final StoreGroup group;
  final VoidCallback onTap;
  final bool loadLogos;

  @override
  Widget build(BuildContext context) {
    final count = group.productCount;
    final purchased = group.purchasedCount;
    final details = [
      count == 1 ? '1 product' : '$count products',
      if (purchased > 0) '$purchased purchased',
    ].join(' · ');
    return Material(
      color: WhyNotColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              StoreLogo(
                domain: group.domain,
                name: group.name,
                loadImage: loadLogos,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.domain,
                      style: WhyNotTextStyles.muted(size: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(details, style: WhyNotTextStyles.muted(size: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatStorePrice(group.pendingValue),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text('to buy', style: WhyNotTextStyles.muted(size: 11)),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WhyNotColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
