import 'package:flutter/material.dart';

import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../domain/nearby_store.dart';

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

class _NearbyStoreSectionState extends State<NearbyStoreSection> {
  /// Future containing the store selected for the user's current location.
  ///
  /// It is stored in state so rebuilding the widget does not request the
  /// device location repeatedly.
  Future<NearbyStore?>? _storeFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _storeFuture ??=
        context.dependencies.nearbyStoreController.getNearestStore();
  }

  /// Requests the current location and nearby store again.
  void _retry() {
    setState(() {
      _storeFuture =
          context.dependencies.nearbyStoreController.getNearestStore();
    });
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
    return FutureBuilder<NearbyStore?>(
      future: _storeFuture,
      builder: (context, snapshot) {
        // The app is obtaining the current location and requesting a store.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _NearbyStoreLoadingCard();
        }

        // Location permission, device location, or backend request failed.
        if (snapshot.hasError) {
          return _NearbyStoreErrorCard(
            error: snapshot.error,
            onRetry: _retry,
          );
        }

        final store = snapshot.data;

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
  });

  final NearbyStore store;
  final String formattedDistance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreImage(
            imageUrl: store.imageUrl,
          ),

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
                        formattedDistance,
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
    );
  }
}

/// Displays the store image returned by the backend.
///
/// A neutral fallback is shown when no image is available or the network
/// image cannot be loaded.
class _StoreImage extends StatelessWidget {
  const _StoreImage({
    required this.imageUrl,
  });

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
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
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
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  bool get _isLocationError {
    final message = error.toString().toLowerCase();

    return message.contains('location') ||
        message.contains('permission');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLocationError
        ? 'We need your location'
        : 'We could not load nearby stores';

    final message = _isLocationError
        ? 'Allow location access so WhyNot can find something nearby for you.'
        : 'Something went wrong while finding a nearby store. Please try again.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhyNotColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 22,
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 24,
            color: WhyNotColors.muted.withValues(alpha: 0.65),
          ),

          const SizedBox(height: 10),

          Text(
            title,
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.serif(size: 18),
          ),

          const SizedBox(height: 7),

          Text(
            message,
            textAlign: TextAlign.center,
            style: WhyNotTextStyles.muted(size: 11),
          ),

          const SizedBox(height: 10),

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