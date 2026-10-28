import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/nearby_store_controller.dart';
import '../../models/category_catalog.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/connectivity_message.dart';
import '../widgets/form_controls.dart';

/// Shows the store already selected on Home, without requesting location again.
class NearbyStoreDetailScreen extends StatelessWidget {
  const NearbyStoreDetailScreen({super.key});

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final result = arguments is NearbyStoreResult ? arguments : null;
    final store = result?.store;
    final categories =
        store?.categoryIds.where((id) => id != 'travel').toList() ?? <String>[];
    final connectivity =
        context.dependencies.nearbyStoreController.connectivity;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: connectivity,
          builder: (context, _) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => _goBack(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Nearby store',
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
                ),
                const SizedBox(height: 27),
                if (store == null) ...[
                  const SizedBox(height: 70),
                  const Icon(Icons.storefront_outlined, size: 48),
                  const SizedBox(height: 22),
                  Text(
                    'No store selected',
                    textAlign: TextAlign.center,
                    style: WhyNotTextStyles.serif(size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open a nearby store from Home to see its details.',
                    textAlign: TextAlign.center,
                    style: WhyNotTextStyles.muted(size: 13),
                  ),
                  const SizedBox(height: 28),
                  PillButton(
                    label: 'Back to home',
                    onPressed: () => _goBack(context),
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: store.imageUrl.trim().isEmpty
                          ? const _StoreImageFallback()
                          : Image.network(
                              store.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      color: WhyNotColors.card,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                              errorBuilder: (_, _, _) =>
                                  const _StoreImageFallback(),
                            ),
                    ),
                  ),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14),
                          SizedBox(width: 6),
                          Text('Near you', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(store.name, style: WhyNotTextStyles.serif(size: 30)),
                  const SizedBox(height: 12),
                  Text(
                    '${result!.stale || connectivity.isOffline ? 'Last checked · ' : ''}'
                    '${store.distanceKm < 1 ? '${(store.distanceKm * 1000).round()} m' : '${store.distanceKm.toStringAsFixed(1)} km'} away',
                    style: WhyNotTextStyles.muted(size: 14),
                  ),
                  if (result.stale || connectivity.isOffline) ...[
                    const SizedBox(height: 22),
                    ConnectivityNotice(
                      label: connectivity.isOffline
                          ? 'Offline'
                          : 'May be outdated',
                      title: 'Last nearby match',
                      message:
                          'Store details and distance may have changed. Return to Home to check the latest nearby match.',
                      icon: connectivity.isOffline
                          ? Icons.wifi_off_rounded
                          : Icons.history_rounded,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: WhyNotColors.form,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visit this store',
                          style: WhyNotTextStyles.serif(size: 19),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          store.address.trim().isEmpty
                              ? 'Address unavailable'
                              : store.address,
                          style: WhyNotTextStyles.muted(size: 13),
                        ),
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in categories)
                                Chip(
                                  label: Text(
                                    CategoryCatalog.labelsById[id] ?? id,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (store.websiteUrl.trim().isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Text(
                      'Store website',
                      style: WhyNotTextStyles.serif(size: 19),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      store.websiteUrl,
                      style: WhyNotTextStyles.muted(size: 12),
                    ),
                  ],
                  const SizedBox(height: 28),
                  PillButton(
                    label: 'Back to home',
                    onPressed: () => _goBack(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
    );
  }
}

class _StoreImageFallback extends StatelessWidget {
  const _StoreImageFallback();

  @override
  Widget build(BuildContext context) => Container(
    color: WhyNotColors.card,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.storefront_outlined,
          size: 42,
          color: WhyNotColors.muted,
        ),
        const SizedBox(height: 8),
        Text('Image unavailable', style: WhyNotTextStyles.muted(size: 11)),
      ],
    ),
  );
}
