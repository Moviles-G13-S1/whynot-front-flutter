/// Domain model representing a single personalized product recommendation.
///
/// The Smart Recommendation backend returns at most one product for the
/// current user.
class ProductRecommendation {
  const ProductRecommendation({
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.productUrl,
    required this.categoryId,
    required this.reason,
  });

  /// Product name displayed to the user.
  final String name;

  /// Brand associated with the recommended product.
  final String brand;

  /// Product price returned by the backend.
  final double price;

  /// URL of the image used to visually represent the product.
  ///
  /// The presentation layer is responsible for displaying a fallback when
  /// this URL is empty or cannot be loaded.
  final String imageUrl;

  /// Original product URL associated with the recommendation.
  ///
  /// The current version of the Smart Feature does not navigate to this URL,
  /// but it is kept in the domain model because it is part of the backend
  /// response and can be used in future interactions.
  final String productUrl;

  /// Identifier of the product category.
  final String categoryId;

  /// Human-readable explanation describing why the product was recommended.
  final String reason;
}