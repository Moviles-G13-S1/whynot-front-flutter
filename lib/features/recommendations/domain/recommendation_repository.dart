import 'product_recommendation.dart';

/// Domain contract for obtaining personalized product recommendations.
///
/// The domain layer defines only the capability required by the application.
/// It does not know whether the recommendation comes from Firebase,
/// another API, a local source, or a test implementation.
abstract interface class RecommendationRepository {
  /// Returns one personalized recommendation for the current user.
  ///
  /// A null result is valid and indicates that no eligible recommendation
  /// was available.
  Future<ProductRecommendation?> getRecommendation();
}