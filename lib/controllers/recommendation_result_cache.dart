import 'dart:collection';

import '../models/product_recommendation.dart';

typedef CacheClock = DateTime Function();

class RecommendationCacheStats {
  const RecommendationCacheStats({
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.expirations,
    required this.coalesced,
  });

  final int hits;
  final int misses;
  final int evictions;
  final int expirations;
  final int coalesced;
}

class _CacheEntry {
  const _CacheEntry(this.value, this.expiresAt);
  final ProductRecommendation? value;
  final DateTime expiresAt;
}

/// Santiago Casasbuenas: Bounded, process-local LRU for recommendation results.
/// Successful results live 5 minutes; a valid null result lives 30 seconds.
/// The backend accepts no request fields, so the authenticated UID is the full
/// request key. If inputs are added to the callable, extend this key as well.
class RecommendationResultCache {
  RecommendationResultCache({
    this.capacity = 8,
    this.resultTtl = const Duration(minutes: 5),
    this.emptyTtl = const Duration(seconds: 30),
    CacheClock? clock,
  }) : assert(capacity > 0),
       _clock = clock ?? DateTime.now;

  final int capacity;
  final Duration resultTtl;
  final Duration emptyTtl;
  final CacheClock _clock;
  final LinkedHashMap<String, _CacheEntry> _entries = LinkedHashMap();
  int _hits = 0, _misses = 0, _evictions = 0, _expirations = 0, _coalesced = 0;

  RecommendationCacheStats get stats => RecommendationCacheStats(
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
    expirations: _expirations,
    coalesced: _coalesced,
  );

  int get length => _entries.length;

  /// Santiago Casasbuenas: A hit moves its entry to the newest LRU position;
  /// expiry removes it before the repository is asked for a fresh result.
  (bool, ProductRecommendation?) lookup(String userId) {
    final entry = _entries.remove(userId);
    if (entry == null) {
      _misses++;
      return (false, null);
    }
    if (!_clock().isBefore(entry.expiresAt)) {
      _expirations++;
      _misses++;
      return (false, null);
    }
    _entries[userId] = entry;
    _hits++;
    return (true, entry.value);
  }

  /// Santiago Casasbuenas: Evict the oldest entry after a successful fetch.
  /// Errors are never stored; null has a shorter TTL so new products surface.
  void store(String userId, ProductRecommendation? value) {
    _entries.remove(userId);
    _entries[userId] = _CacheEntry(
      value,
      _clock().add(value == null ? emptyTtl : resultTtl),
    );
    if (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
      _evictions++;
    }
  }

  void invalidate(String userId) => _entries.remove(userId);

  void clear() => _entries.clear();

  void recordCoalesced() => _coalesced++;
}
