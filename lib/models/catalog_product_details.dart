import 'product_recommendation.dart';
import 'recommendation_catalog_item.dart';

/// Reusable display fields; a saveable recommendation event is never cached.
class CatalogProductDetails {
  const CatalogProductDetails({
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.productUrl,
    required this.categoryId,
    required this.reason,
  });

  factory CatalogProductDetails.fromRecommendation(
    ProductRecommendation recommendation,
  ) => CatalogProductDetails(
    name: recommendation.name,
    brand: recommendation.brand,
    price: recommendation.price,
    imageUrl: recommendation.imageUrl,
    productUrl: recommendation.productUrl,
    categoryId: recommendation.categoryId,
    reason: recommendation.reason,
  );

  /// Catalog rows can preview the detail page before the save event is ready.
  factory CatalogProductDetails.fromCatalogItem(
    RecommendationCatalogItem item,
  ) => CatalogProductDetails(
    name: item.name,
    brand: item.brand,
    price: item.price,
    imageUrl: item.imageUrl,
    productUrl: '',
    categoryId: item.categoryId,
    reason: item.reason,
  );

  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final String productUrl;
  final String categoryId;
  final String reason;

  ProductRecommendation withEvent(String eventId) => ProductRecommendation(
    recommendationEventId: eventId,
    name: name,
    brand: brand,
    price: price,
    imageUrl: imageUrl,
    productUrl: productUrl,
    categoryId: categoryId,
    reason: reason,
  );
}
