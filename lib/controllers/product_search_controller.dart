import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/product.dart';

typedef ProductSearchRequest = ({
  List<Product> products,
  String query,
  String? categoryId,
  double? minPrice,
  double? maxPrice,
});

// A top-level callback receives only plain product data, not UI or Firebase.
List<Product> _filterInWorker(ProductSearchRequest request) =>
    const ProductSearchController().filter(
      request.products,
      query: request.query,
      categoryId: request.categoryId,
      minPrice: request.minPrice,
      maxPrice: request.maxPrice,
    );

/// Filtering can run in a background isolate on native Flutter.
class ProductSearchController {
  const ProductSearchController();

  Future<List<Product>> filterAsync(ProductSearchRequest request) =>
      compute(_filterInWorker, request, debugLabel: 'product_search_worker');

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
