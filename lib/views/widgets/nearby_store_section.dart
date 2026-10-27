import 'package:flutter/material.dart';

import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/nearby_store.dart';
import '../../models/nearby_failure.dart';
import '../../controllers/nearby_store_controller.dart';
import '../../controllers/connectivity_status.dart';
import 'connectivity_message.dart';

/// Displays the Context-Aware nearby-store recommendation.
///
/// This widget does not access Geolocator or Firebase directly.
///
/// Architecture:
///
/// NearbyStoreSection
/// → NearbyStoreController
/// → LocationRepository
/// → NearbyStoreRepository
///
/// The controller first obtains the device's current location and then asks
/// the backend for the nearest relevant store.
///
/// The user's coordinates are only used for the request and are not persisted.
class NearbyStoreSection extends StatefulWidget {
  const NearbyStoreSection({super.key});

  @override
  State<NearbyStoreSection> createState() => _NearbyStoreSectionState();
}

class _NearbyStoreSectionState extends State<NearbyStoreSection>
    with WidgetsBindingObserver {
  /// Future containing the store selected for the user's current location.
  ///
  /// It is stored in state so rebuilding the widget does not request the
  /// device location repeatedly.
  Future<(NearbyStoreResult?, NearbyFailureKind?)>? _storeFuture;
  NearbyStoreController? _controller;
  NetworkStatus _network = NetworkStatus.unknown;

  void _networkChanged() {
    final status = _controller?.connectivity.status ?? NetworkStatus.unknown;
    if (status == _network) return;
    final wasOffline = _network == NetworkStatus.offline;
    setState(() => _network = status);
    if (wasOffline && status == NetworkStatus.available) _retry();
  }

  bool _awaitingSettingsReturn = false;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.connectivity.removeListener(_networkChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettingsReturn) {
      _awaitingSettingsReturn = false;
      _retry(requestPermission: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = context.dependencies.nearbyStoreController;
    if (_controller != controller) {
      _controller?.connectivity.removeListener(_networkChanged);
      _controller = controller;
      _network = controller.connectivity.status;
      controller.connectivity.addListener(_networkChanged);
      _storeFuture = _load();
    }
  }

  Future<(NearbyStoreResult?, NearbyFailureKind?)> _load({
    bool requestPermission = true,
  }) async {
    try {
      final store = await context.dependencies.nearbyStoreController
          .getNearestStoreResult(requestPermission: requestPermission);
      return (store, null);
    } on NearbyFailure catch (failure) {
      return (null, failure.kind);
    } catch (_) {
      return (null, NearbyFailureKind.nearbyServiceUnavailable);
    }
  }

  /// Requests the current location and nearby store again.
  void _retry({bool requestPermission = true}) {
    setState(() {
      _storeFuture = _load(requestPermission: requestPermission);
    });
  }

  Future<void> _openSettings(NearbyFailureKind kind) async {
    if (_openingSettings || _awaitingSettingsReturn) return;
    _openingSettings = true;
    _awaitingSettingsReturn = true;
    try {
      final controller = context.dependencies.nearbyStoreController;
      final opened = kind == NearbyFailureKind.servicesDisabled
          ? await controller.openLocationSettings()
          : await controller.openAppSettings();
      if (!opened) _awaitingSettingsReturn = false;
    } catch (_) {
      _awaitingSettingsReturn = false;
    } finally {
      _openingSettings = false;
    }
  }

  /// Formats the backend distance in a compact, user-friendly form.
  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    }

    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(NearbyStoreResult?, NearbyFailureKind?)>(
      future: _storeFuture,
      builder: (context, snapshot) {
        // The app is obtaining the current location and requesting a store.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _NearbyStoreLoadingCard();
        }

        // Location permission, device location, or backend request failed.
        final kind = snapshot.data?.$2;
        if (kind != null) {
          return _NearbyStoreErrorCard(
            kind: kind,
            offline: _controller?.connectivity.isOffline == true,
            onAction:
                kind == NearbyFailureKind.permissionPermanentlyDenied ||
                    kind == NearbyFailureKind.servicesDisabled
                ? () => _openSettings(kind)
                : () => _retry(),
          );
        }

        final result = snapshot.data?.$1;
        final store = result?.store;

        // A null store is a valid backend response.
        //
        // Instead of exposing a technical empty state, the UI explains that
        // there is simply no useful nearby recommendation available yet.
        if (store == null) {
          return const _NoNearbyStoreCard();
        }

        return _NearbyStoreCard(
          store: store,
          formattedDistance: _formatDistance(store.distanceKm),
          stale: result!.stale,
          offline: _controller?.connectivity.isOffline == true,
          onRetry: _retry,
        );
      },
    );
  }
}

/// Card displayed when the Context-Aware backend returns a store.
class _NearbyStoreCard extends StatelessWidget {
  const _NearbyStoreCard({
    required this.store,
    required this.formattedDistance,
    required this.stale,
    required this.offline,
    required this.onRetry,
  });

  final NearbyStore store;
  final String formattedDistance;
  final bool stale;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale) ...[
            ConnectivityNotice(
              label: offline ? 'Offline · outdated' : 'May be outdated',
              title: 'Last nearby match',
              message: offline
                  ? 'This store and its distance may have changed. We’ll check again when you reconnect.'
                  : 'We couldn’t update this match. Store details and distance may have changed.',
              icon: offline ? Icons.wifi_off_rounded : Icons.history_rounded,
              actionLabel: offline ? null : 'Try again',
              onAction: offline ? null : onRetry,
              backgroundColor: WhyNotColors.background,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StoreImage(imageUrl: store.imageUrl),

              const SizedBox(width: 16),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WhyNotTextStyles.serif(size: 20),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        store.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WhyNotTextStyles.muted(size: 11),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: WhyNotColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stale
                                ? 'Last checked · $formattedDistance'
                                : formattedDistance,
                            style: WhyNotTextStyles.muted(size: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays the store image returned by the backend.
///
/// A neutral fallback is shown when no image is available or the network
/// image cannot be loaded.
class _StoreImage extends StatelessWidget {
  const _StoreImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 105,
        height: 125,
        child: imageUrl.trim().isEmpty
            ? const _StoreImageFallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _StoreImageFallback();
                },
              ),
      ),
    );
  }
}

/// Fallback displayed when the store does not have a usable image.
class _StoreImageFallback extends StatelessWidget {
  const _StoreImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhyNotColors.background,
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_outlined,
        size: 29,
        color: WhyNotColors.muted.withValues(alpha: 0.65),
      ),
    );
  }
}

/// Loading state displayed while location and store data are being obtained.
class _NearbyStoreLoadingCard extends StatelessWidget {
  const _NearbyStoreLoadingCard();

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

/// Friendly empty state displayed when no nearby store can be recommended.
///
/// A null response is expected behavior and does not represent an error.
class _NoNearbyStoreCard extends StatelessWidget {
  const _NoNearbyStoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 24,
            color: WhyNotColors.muted.withValues(alpha: 0.65),
          ),

          const SizedBox(height: 10),

          Text(
            'Nothing nearby just yet.',
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.serif(size: 18),
          ),

          const SizedBox(height: 7),

          Text(
            'We could not find a nearby store that fits your preferences right now.',
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.muted(size: 11),
          ),
        ],
      ),
    );
  }
}

/// Error state displayed when location or backend access fails.
///
/// The message is intentionally user-facing and does not expose raw Firebase
/// or platform errors.
class _NearbyStoreErrorCard extends StatelessWidget {
  const _NearbyStoreErrorCard({
    required this.kind,
    required this.onAction,
    this.offline = false,
  });

  final NearbyFailureKind kind;
  final VoidCallback onAction;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final (label, title, message, action, icon) = switch (kind) {
      NearbyFailureKind.permissionDenied => (
        'Location needed',
        'Location permission denied',
        'Allow location access to see nearby stores picked for you.',
        'Try permission again',
        Icons.location_off_outlined,
      ),
      NearbyFailureKind.permissionPermanentlyDenied => (
        'Location needed',
        'Location permission denied',
        'Enable location access for WhyNot in app settings.',
        'Open app settings',
        Icons.location_off_outlined,
      ),
      NearbyFailureKind.servicesDisabled => (
        'Location is off',
        'Location services are off',
        'Turn on device location services to find a store near you.',
        'Open location settings',
        Icons.location_off_outlined,
      ),
      NearbyFailureKind.locationUnavailable => (
        'Location unavailable',
        'Could not get your location',
        'Your location signal is unavailable. Move to an open area and try again.',
        'Try again',
        Icons.my_location_outlined,
      ),
      NearbyFailureKind.nearbyServiceUnavailable => (
        offline ? 'Offline' : 'Could not refresh',
        offline
            ? 'Nearby picks are waiting'
            : 'Nearby picks are taking a moment',
        offline
            ? 'Connect to search near your current location. We’ll try again when you’re back.'
            : 'We couldn’t reach nearby stores just now. Give it another try.',
        'Try again',
        offline ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
      ),
    };

    return ConnectivityNotice(
      label: label,
      title: title,
      message: message,
      icon: icon,
      actionLabel: action,
      onAction: onAction,
      backgroundColor: WhyNotColors.card,
    );
  }
}
