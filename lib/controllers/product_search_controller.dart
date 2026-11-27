import 'dart:developer' as developer;

import '../models/product.dart';

/// Baseline prototype: synchronous filtering, before optimization.
class ProductSearchController {
  const ProductSearchController();

  List<Product> filter(
    List<Product> products, {
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
  }) {
    return developer.Timeline.timeSync('product_search_filter', () {
      final term = query.trim().toLowerCase();
      final results = products.where((product) {
        final matchesText =
            product.name.toLowerCase().contains(term) ||
            product.brand.toLowerCase().contains(term);
        return matchesText &&
            (categoryId == null || product.categoryId == categoryId) &&
            (minPrice == null || product.price >= minPrice) &&
            (maxPrice == null || product.price <= maxPrice);
      }).toList();
      results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return results;
    });
  }
}
