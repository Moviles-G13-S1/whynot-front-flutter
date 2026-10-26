import '../models/product_recommendation.dart';
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
    RecommendationResultCache? cache,
  }) : _recommendationRepository = recommendationRepository,
       _authRepository = authRepository,
       cache = cache ?? RecommendationResultCache();

  /// Repository used to obtain personalized recommendations.
  ///
  /// The controller depends on the repository contract instead of a concrete
  /// Firebase implementation, which keeps this layer testable and decoupled
  /// from the backend technology.
  final RecommendationRepository _recommendationRepository;
  final AuthRepository _authRepository;
  final RecommendationResultCache cache;
  final Map<String, Future<ProductRecommendation?>> _inFlight = {};
  final Map<String, int> _versions = {};
  int _epoch = 0;
  String? _activeUserId;

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
      final (hit, value) = cache.lookup(userId);
      if (hit) return Future.value(value);
      final pending = _inFlight[userId];
      if (pending != null) {
        cache.recordCoalesced();
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
      cache.store(userId, value);
      return value;
    } finally {
      if (_epoch == epoch && (_versions[userId] ?? 0) == version) {
        _inFlight.remove(userId);
      }
    }
  }

  /// Santiago Casasbuenas: Mutations invalidate the affected user's result and
  /// prevent an older request from repopulating it after the mutation succeeds.
  void invalidateForUser(String userId) {
    cache.invalidate(userId);
    _versions[userId] = (_versions[userId] ?? 0) + 1;
    _inFlight.remove(userId);
  }

  /// Santiago Casasbuenas: Explicit auth transitions discard every entry and
  /// in-flight completion. This cache never survives an application restart.
  void clearCache() {
    _epoch++;
    cache.clear();
    _versions.clear();
    _inFlight.clear();
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
