import '../models/recommendation_catalog_item.dart';
import 'recommendation_result_cache.dart';

/// One expiring catalog snapshot for the signed-in user.
/// The controller clears it on auth changes and local recommendation inputs.
class RecommendationCatalogSnapshotCache {
  RecommendationCatalogSnapshotCache({
    this.resultTtl = const Duration(minutes: 5),
    this.emptyTtl = const Duration(seconds: 30),
    CacheClock? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration resultTtl;
  final Duration emptyTtl;
  final CacheClock _clock;
  String? _userId;
  List<RecommendationCatalogItem>? _items;
  DateTime? _expiresAt;

  (bool, List<RecommendationCatalogItem>) lookup(String userId) {
    final expiresAt = _expiresAt;
    if (_userId != userId ||
        expiresAt == null ||
        !_clock().isBefore(expiresAt)) {
      return (false, const []);
    }
    return (true, _items!);
  }

  /// Only nonempty results are useful as an extended offline fallback.
  List<RecommendationCatalogItem>? staleFor(String userId) =>
      _userId == userId && _items?.isNotEmpty == true ? _items : null;

  void store(String userId, List<RecommendationCatalogItem> items) {
    _userId = userId;
    _items = List.unmodifiable(items);
    _expiresAt = _clock().add(items.isEmpty ? emptyTtl : resultTtl);
  }

  void invalidate(String userId) {
    if (_userId == userId) clear();
  }

  void clear() {
    _userId = null;
    _items = null;
    _expiresAt = null;
  }
}
