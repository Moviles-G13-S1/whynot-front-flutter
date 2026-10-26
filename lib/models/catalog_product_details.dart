import 'product_recommendation.dart';

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
