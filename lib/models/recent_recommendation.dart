import 'catalog_product_details.dart';

/// An account's local browsing history entry. It has no saveable event.
class RecentRecommendation {
  const RecentRecommendation({
    required this.sourceProductId,
    required this.details,
    required this.openedAt,
  });

  final String sourceProductId;
  final CatalogProductDetails details;
  final DateTime openedAt;
}
