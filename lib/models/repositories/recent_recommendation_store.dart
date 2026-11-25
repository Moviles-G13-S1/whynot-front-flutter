import '../catalog_product_details.dart';
import '../recent_recommendation.dart';

/// Local browsing history. Callers scope every operation by the signed-in UID.
abstract interface class RecentRecommendationStore {
  Future<List<RecentRecommendation>> read(String userId);

  /// Returns the order assigned to this visit.
  Future<int> record(String userId, RecentRecommendation entry);

  /// Refreshes display fields only if the same visit is still retained.
  Future<void> refreshDetails(
    String userId,
    String sourceProductId,
    int openOrder,
    CatalogProductDetails details,
  );

  Future<void> clear(String userId);
}
