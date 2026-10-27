import 'dart:async';

import '../models/catalog_product_details.dart';
import '../models/product_recommendation.dart';
import '../models/recommendation_catalog_item.dart';
import '../models/repositories/recommendation_repository.dart';
import '../models/repositories/auth_repository.dart';
import 'recommendation_catalog_snapshot_cache.dart';
import 'recommendation_result_cache.dart';
import 'connectivity_status.dart';

/// Data shown immediately while the server prepares a fresh save event.
typedef RecommendationLoad = ({ProductRecommendation? value, Object? error});

class CatalogOpenRequest {
  const CatalogOpenRequest({
    required this.sourceProductId,
    required this.preview,
    required this.recommendation,
  });

  final String sourceProductId;
  final CatalogProductDetails preview;
  final Future<RecommendationLoad> recommendation;
}

/// Controller for personalized product recommendations.
///
/// The controller acts as the entry point between views
/// and the recommendation repository.
///
/// Architecture:
///
/// View
/// → RecommendationController
/// → RecommendationRepository
///
/// It intentionally contains no Firebase-specific logic.
class RecommendationController {
  RecommendationController({
    required RecommendationRepository recommendationRepository,
    required AuthRepository authRepository,
    RecommendationResultCache<ProductRecommendation>? cache,
    RecommendationCatalogSnapshotCache? catalogSnapshotCache,
    RecommendationResultCache<CatalogProductDetails>? catalogProductCache,
    ConnectivityStatus? connectivity,
  }) : _recommendationRepository = recommendationRepository,
       _authRepository = authRepository,
       connectivity = connectivity ?? ConnectivityStatus(observe: false),
       _cache = cache ?? RecommendationResultCache<ProductRecommendation>(),
       _catalogSnapshotCache =
           catalogSnapshotCache ?? RecommendationCatalogSnapshotCache(),
       _catalogProductCache =
           catalogProductCache ??
           RecommendationResultCache<CatalogProductDetails>(capacity: 5);

  /// Repository used to obtain personalized recommendations.
  ///
  /// The controller depends on the repository contract instead of a concrete
  /// Firebase implementation, which keeps this layer testable and decoupled
  /// from the backend technology.
  final RecommendationRepository _recommendationRepository;
  final AuthRepository _authRepository;
  final ConnectivityStatus connectivity;
  final RecommendationResultCache<ProductRecommendation> _cache;
  final RecommendationCatalogSnapshotCache _catalogSnapshotCache;
  final RecommendationResultCache<CatalogProductDetails> _catalogProductCache;

  RecommendationCacheStats get cacheStats => _cache.stats;
  int get cachedEntryCount => _cache.length;
  final Map<String, Future<ProductRecommendation?>> _inFlight = {};
  final Map<String, Future<List<RecommendationCatalogItem>>> _catalogInFlight =
      {};
  final Map<String, int> _versions = {};
  final Map<String, int> _catalogVersions = {};
  final StreamController<String> _invalidations = StreamController.broadcast();
  int _epoch = 0;
  String? _activeUserId;

  /// A successful local change asks mounted recommendation views to reload.
  Stream<String> get invalidations => _invalidations.stream;

  ProductRecommendation? get staleRecommendation {
    final userId = _authRepository.currentUser?.id;
    if (userId == null || _activeUserId != userId) return null;
    return _cache.staleFor(userId);
  }

  List<RecommendationCatalogItem>? get staleCatalog {
    final userId = _authRepository.currentUser?.id;
    if (userId == null || _activeUserId != userId) return null;
    return _catalogSnapshotCache.staleFor(userId);
  }

  /// Returns the personalized product recommendation for the current user.
  ///
  /// A null result is valid and means the backend did not find an eligible
  /// product to recommend.
  Future<ProductRecommendation?> getRecommendation({
    bool forceRefresh = false,
    bool checkConnection = false,
  }) {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      clearCache();
      return Future.error(StateError('No user logged in.'));
    }
    if (_activeUserId != userId) {
      // Santiago Casasbuenas: A user switch drops all previous user data.
      clearCache();
      _activeUserId = userId;
    }
    if (connectivity.isOffline && !checkConnection) {
      return Future.error(
        StateError('Offline: new recommendations unavailable.'),
      );
    }
    if (!forceRefresh) {
      final (hit, value) = _cache.lookup(userId);
      if (hit) return Future.value(value);
      final pending = _inFlight[userId];
      if (pending != null) {
        _cache.recordCoalesced();
        return pending;
      }
    } else {
      // Santiago Casasbuenas: Retry bypasses a valid hit and supersedes an
      // older in-flight request, while leaving a valid entry for error recovery.
      _versions[userId] = (_versions[userId] ?? 0) + 1;
      _inFlight.remove(userId);
    }
    final version = _versions[userId] ?? 0;
    final request = _fetch(userId, version, _epoch, checkConnection);
    _inFlight[userId] = request;
    return request;
  }

  Future<ProductRecommendation?> _fetch(
    String userId,
    int version,
    int epoch,
    bool checkConnection,
  ) async {
    try {
      final value = await _recommendationRepository.getRecommendation();
      if (_authRepository.currentUser?.id != userId ||
          _activeUserId != userId ||
          _epoch != epoch) {
        throw StateError('Recommendation user changed during request.');
      }
      if ((_versions[userId] ?? 0) != version) {
        throw StateError('Recommendation changed during request.');
      }
      _cache.store(userId, value);
      if (checkConnection) connectivity.confirmReachable();
      return value;
    } finally {
      if (_epoch == epoch && (_versions[userId] ?? 0) == version) {
        _inFlight.remove(userId);
      }
    }
  }

  /// A single expiring snapshot avoids fetching the full list on every visit.
  Future<({List<RecommendationCatalogItem> items, bool fromCache})> getCatalog({
    bool forceRefresh = false,
    bool checkConnection = false,
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      clearCache();
      throw StateError('No user logged in.');
    }
    if (_activeUserId != userId) {
      clearCache();
      _activeUserId = userId;
    }
    if (connectivity.isOffline && !checkConnection) {
      throw StateError('Offline: new recommendations unavailable.');
    }
    if (!forceRefresh) {
      final (hit, cached) = _catalogSnapshotCache.lookup(userId);
      if (hit) return (items: cached, fromCache: true);
      final pending = _catalogInFlight[userId];
      if (pending != null) {
        return (items: await pending, fromCache: false);
      }
    } else {
      _catalogVersions[userId] = (_catalogVersions[userId] ?? 0) + 1;
      _catalogInFlight.remove(userId);
    }
    final version = _catalogVersions[userId] ?? 0;
    final pending = _fetchCatalog(userId, version, _epoch, checkConnection);
    _catalogInFlight[userId] = pending;
    return (items: await pending, fromCache: false);
  }

  Future<List<RecommendationCatalogItem>> _fetchCatalog(
    String userId,
    int version,
    int epoch,
    bool checkConnection,
  ) async {
    try {
      final items = await _recommendationRepository.getCatalog();
      if (_authRepository.currentUser?.id != userId ||
          _activeUserId != userId ||
          _epoch != epoch ||
          (_catalogVersions[userId] ?? 0) != version) {
        throw StateError('Recommendation catalog changed during request.');
      }
      _catalogSnapshotCache.store(userId, items);
      if (checkConnection) connectivity.confirmReachable();
      return items;
    } finally {
      if (_epoch == epoch && (_catalogVersions[userId] ?? 0) == version) {
        _catalogInFlight.remove(userId);
      }
    }
  }

  String _catalogProductKey(String userId, String sourceProductId) =>
      '${userId.length}:$userId:$sourceProductId';

  bool isCatalogProductCached(String sourceProductId) {
    final userId = _authRepository.currentUser?.id;
    return userId != null &&
        _catalogProductCache.containsFresh(
          _catalogProductKey(userId, sourceProductId),
        );
  }

  CatalogOpenRequest beginCatalogOpen(RecommendationCatalogItem item) {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) throw StateError('No user logged in.');
    final key = _catalogProductKey(userId, item.sourceProductId);
    final cached =
        _catalogProductCache.peek(key) ?? _catalogProductCache.staleFor(key);
    return CatalogOpenRequest(
      sourceProductId: item.sourceProductId,
      preview: cached ?? CatalogProductDetails.fromCatalogItem(item),
      recommendation: openCatalogItem(item.sourceProductId)
          .then<RecommendationLoad>(
            (value) => (value: value, error: null),
            onError: (Object error) => (value: null, error: error),
          ),
    );
  }

  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) throw StateError('No user logged in.');
    if (connectivity.isOffline) {
      throw StateError('Offline: saving is unavailable.');
    }
    final epoch = _epoch;
    final version = _catalogVersions[userId] ?? 0;
    final key = _catalogProductKey(userId, sourceProductId);
    final (hit, cached) = _catalogProductCache.lookup(key);
    try {
      if (hit && cached != null) {
        // Always recheck eligibility and issue a new saveable event.
        final eventId = await _recommendationRepository.createCatalogEvent(
          sourceProductId,
        );
        if (_authRepository.currentUser?.id != userId ||
            _activeUserId != userId ||
            _epoch != epoch ||
            (_catalogVersions[userId] ?? 0) != version) {
          throw StateError('Recommendation changed during request.');
        }
        return cached.withEvent(eventId);
      }
      final recommendation = await _recommendationRepository.openCatalogItem(
        sourceProductId,
      );
      if (_authRepository.currentUser?.id != userId ||
          _activeUserId != userId ||
          _epoch != epoch ||
          (_catalogVersions[userId] ?? 0) != version) {
        throw StateError('Recommendation changed during request.');
      }
      _catalogProductCache.store(
        key,
        CatalogProductDetails.fromRecommendation(recommendation),
      );
      return recommendation;
    } catch (_) {
      _catalogProductCache.invalidate(key);
      rethrow;
    }
  }

  /// Santiago Casasbuenas: Mutations invalidate the affected user's result and
  /// prevent an older request from repopulating it after the mutation succeeds.
  void invalidateForUser(String userId) {
    _cache.invalidate(userId);
    _catalogSnapshotCache.invalidate(userId);
    _catalogProductCache.clear();
    _versions[userId] = (_versions[userId] ?? 0) + 1;
    _catalogVersions[userId] = (_catalogVersions[userId] ?? 0) + 1;
    _inFlight.remove(userId);
    _catalogInFlight.remove(userId);
    // Santiago Casasbuenas: Cache invalidation must also replace the Future
    // held by a mounted view; otherwise Home keeps showing the old card.
    _invalidations.add(userId);
  }

  /// Santiago Casasbuenas: Explicit auth transitions discard every entry and
  /// in-flight completion. This cache never survives an application restart.
  void clearCache() {
    _epoch++;
    _cache.clear();
    _catalogSnapshotCache.clear();
    _catalogProductCache.clear();
    _versions.clear();
    _catalogVersions.clear();
    _inFlight.clear();
    _catalogInFlight.clear();
    _activeUserId = null;
  }

  Future<void> recordHomeCardEvent({
    required String impressionId,
    required String recommendationEventId,
    required String eventType,
  }) => _recommendationRepository.recordHomeCardEvent(
    impressionId: impressionId,
    recommendationEventId: recommendationEventId,
    eventType: eventType,
  );

  Future<void> saveRecommendation({
    required ProductRecommendation recommendation,
    required String wishlistId,
  }) async {
    if (connectivity.isOffline) {
      throw StateError('Offline: saving is unavailable.');
    }
    final userId = _authRepository.currentUser?.id;
    await _recommendationRepository.saveRecommendation(
      recommendationEventId: recommendation.recommendationEventId,
      wishlistId: wishlistId,
    );
    if (userId != null) invalidateForUser(userId);
  }
}
