import 'package:flutter/foundation.dart';

import '../infrastructure/cache/ttl_cache.dart';
import '../models/product.dart';
import 'product_search_controller.dart';

typedef _SearchKey = ({
  String query,
  String? categoryId,
  double? minPrice,
  double? maxPrice,
});

/// Screen-scoped, bounded TTL memoization of completed search results.
/// A new account or product-list instance invalidates all previous results.
class ProductSearchResultCache {
  ProductSearchResultCache({
    this.ttl = const Duration(seconds: 60),
    this.maxEntries = 32,
    Duration Function()? elapsed,
    Future<List<Product>> Function(ProductSearchRequest)? worker,
  }) : assert(maxEntries > 0),
       _elapsed = elapsed,
       _worker = worker ?? const ProductSearchController().filterAsync;

  final Duration ttl;
  final int maxEntries;
  final Duration Function()? _elapsed;
  final Future<List<Product>> Function(ProductSearchRequest) _worker;
  final _entries = <_SearchKey, TtlCache<List<Product>>>{};
  String? _ownerId;
  List<Product>? _snapshot;
  int _generation = 0;

  void invalidate() {
    _generation++;
    _entries.clear();
    _ownerId = null;
    _snapshot = null;
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
    final entry = _entries[key];
    final hit = entry?.read();
    if (hit != null) {
      if (kDebugMode) debugPrint('[SearchTTL] HIT');
      return hit;
    }
    if (kDebugMode) {
      debugPrint(entry == null ? '[SearchTTL] MISS' : '[SearchTTL] EXPIRED');
    }
    final generation = _generation;
    final result = List<Product>.unmodifiable(await _worker(request));
    // Never let a worker for an old snapshot repopulate a cleared cache.
    if (generation == _generation) {
      _entries.removeWhere((_, value) => value.read() == null);
      if (!_entries.containsKey(key) && _entries.length >= maxEntries) {
        // FIFO capacity guard, not LRU: reads do not reorder entries.
        _entries.remove(_entries.keys.first);
      }
      final fresh = TtlCache<List<Product>>(ttl: ttl, elapsed: _elapsed);
      fresh.write(result);
      _entries[key] = fresh;
    }
    return result;
  }
}
