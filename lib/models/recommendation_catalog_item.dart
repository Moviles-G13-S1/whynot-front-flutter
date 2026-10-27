/// A candidate product. Opening it obtains a fresh, saveable recommendation
/// event after the backend rechecks eligibility.
class RecommendationCatalogItem {
  const RecommendationCatalogItem({
    required this.sourceProductId,
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    required this.reason,
  });

  final String sourceProductId;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final String categoryId;
  final String reason;
}
