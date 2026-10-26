import 'dart:async';

import '../models/product_recommendation.dart';
import '../models/recommendation_catalog_item.dart';
import '../models/repositories/recommendation_repository.dart';
import '../models/repositories/auth_repository.dart';
import 'recommendation_result_cache.dart';

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
    RecommendationResultCache<List<RecommendationCatalogItem>>? catalogCache,
  }) : _recommendationRepository = recommendationRepository,
       _authRepository = authRepository,
       _cache = cache ?? RecommendationResultCache<ProductRecommendation>(),
       _catalogCache =
           catalogCache ??
           RecommendationResultCache<List<RecommendationCatalogItem>>();

  /// Repository used to obtain personalized recommendations.
  ///
  /// The controller depends on the repository contract instead of a concrete
  /// Firebase implementation, which keeps this layer testable and decoupled
  /// from the backend technology.
  final RecommendationRepository _recommendationRepository;
  final AuthRepository _authRepository;
  final RecommendationResultCache<ProductRecommendation> _cache;
  final RecommendationResultCache<List<RecommendationCatalogItem>>
  _catalogCache;

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

  /// Returns the personalized product recommendation for the current user.
  ///
  /// A null result is valid and means the backend did not find an eligible
  /// product to recommend.
  Future<ProductRecommendation?> getRecommendation({
    bool forceRefresh = false,
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
    final request = _fetch(userId, version, _epoch);
    _inFlight[userId] = request;
    return request;
  }

  Future<ProductRecommendation?> _fetch(
    String userId,
    int version,
    int epoch,
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
      return value;
    } finally {
      if (_epoch == epoch && (_versions[userId] ?? 0) == version) {
        _inFlight.remove(userId);
      }
    }
  }

  /// Santiago Casasbuenas: A catalog revisit reports whether it used the
  /// in-memory list. The first load fetches from the callable; refresh bypasses it.
  Future<({List<RecommendationCatalogItem> items, bool fromCache})> getCatalog({
    bool forceRefresh = false,
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
    if (!forceRefresh) {
      final (hit, cached) = _catalogCache.lookup(userId);
      if (hit) return (items: cached ?? const [], fromCache: true);
      final pending = _catalogInFlight[userId];
      if (pending != null) {
        _catalogCache.recordCoalesced();
        return (items: await pending, fromCache: false);
      }
    } else {
      _catalogVersions[userId] = (_catalogVersions[userId] ?? 0) + 1;
      _catalogInFlight.remove(userId);
    }
    final version = _catalogVersions[userId] ?? 0;
    final pending = _fetchCatalog(userId, version, _epoch);
    _catalogInFlight[userId] = pending;
    return (items: await pending, fromCache: false);
  }

  Future<List<RecommendationCatalogItem>> _fetchCatalog(
    String userId,
    int version,
    int epoch,
  ) async {
    try {
      final items = await _recommendationRepository.getCatalog();
      if (_authRepository.currentUser?.id != userId ||
          _activeUserId != userId ||
          _epoch != epoch ||
          (_catalogVersions[userId] ?? 0) != version) {
        throw StateError('Recommendation catalog changed during request.');
      }
      _catalogCache.store(
        userId,
        items.isEmpty ? null : List.unmodifiable(items),
      );
      return items;
    } finally {
      if (_epoch == epoch && (_catalogVersions[userId] ?? 0) == version) {
        _catalogInFlight.remove(userId);
      }
    }
  }

  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) throw StateError('No user logged in.');
    final epoch = _epoch;
    final recommendation = await _recommendationRepository.openCatalogItem(
      sourceProductId,
    );
    if (_authRepository.currentUser?.id != userId ||
        _activeUserId != userId ||
        _epoch != epoch) {
      throw StateError('Recommendation user changed during request.');
    }
    return recommendation;
  }

  /// Santiago Casasbuenas: Mutations invalidate the affected user's result and
  /// prevent an older request from repopulating it after the mutation succeeds.
  void invalidateForUser(String userId) {
    _cache.invalidate(userId);
    _catalogCache.invalidate(userId);
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
    _catalogCache.clear();
    _versions.clear();
    _catalogVersions.clear();
    _inFlight.clear();
    _catalogInFlight.clear();
    _activeUserId = null;
  }

  Future<void> saveRecommendation({
    required ProductRecommendation recommendation,
    required String wishlistId,
  }) async {
    final userId = _authRepository.currentUser?.id;
    await _recommendationRepository.saveRecommendation(
      recommendationEventId: recommendation.recommendationEventId,
      wishlistId: wishlistId,
    );
    if (userId != null) invalidateForUser(userId);
  }
}
