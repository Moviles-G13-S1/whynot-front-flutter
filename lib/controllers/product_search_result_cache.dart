import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'product_search_controller.dart';

typedef _SearchKey = ({
  String query,
  String? categoryId,
  double? minPrice,
  double? maxPrice,
});

class _LfuEntry {
  _LfuEntry(this.results);

  final List<Product> results;
  int frequency = 1;
}

/// Screen-scoped LFU memoization. No time-based expiry is used.
/// Product-list replacement or account change clears all frequencies and results.
class ProductSearchResultCache {
  ProductSearchResultCache({
    this.maxEntries = 32,
    Future<List<Product>> Function(ProductSearchRequest)? worker,
  }) : assert(maxEntries > 0),
       _worker = worker ?? const ProductSearchController().filterAsync;

  final int maxEntries;
  final Future<List<Product>> Function(ProductSearchRequest) _worker;
  final _entries = <_SearchKey, _LfuEntry>{};
  String? _ownerId;
  List<Product>? _snapshot;
  int _generation = 0;

  void invalidate() {
    _generation++;
    _entries.clear();
    _ownerId = null;
    _snapshot = null;
  }

  void _evictLeastFrequent() {
    // Dart's default Map preserves insertion order. Equal frequencies keep
    // the first candidate (FIFO tie-break), not the least recent access.
    final victim = _entries.entries.reduce(
      (a, b) => a.value.frequency <= b.value.frequency ? a : b,
    );
    _entries.remove(victim.key);
    if (kDebugMode) {
      debugPrint('[SearchLFU] EVICT frequency=${victim.value.frequency}');
    }
  }

  Future<List<Product>> resolve({
    required String ownerId,
    required ProductSearchRequest request,
  }) async {
    if (_ownerId != ownerId || !identical(_snapshot, request.products)) {
      invalidate();
      _ownerId = ownerId;
      _snapshot = request.products;
    }
    final key = (
      query: request.query.trim().toLowerCase(),
      categoryId: request.categoryId,
      minPrice: request.minPrice,
      maxPrice: request.maxPrice,
    );
    final hit = _entries[key];
    if (hit != null) {
      hit.frequency++;
      if (kDebugMode) debugPrint('[SearchLFU] HIT frequency=${hit.frequency}');
      return hit.results;
    }
    if (kDebugMode) debugPrint('[SearchLFU] MISS');
    final generation = _generation;
    final result = List<Product>.unmodifiable(await _worker(request));
    // A stale worker cannot reinsert results after snapshot invalidation.
    if (generation == _generation) {
      // Another concurrent request for this key may have finished first.
      final existing = _entries[key];
      if (existing != null) {
        existing.frequency++;
        return existing.results;
      }
      if (_entries.length >= maxEntries) _evictLeastFrequent();
      _entries[key] = _LfuEntry(result);
    }
    return result;
  }
}
