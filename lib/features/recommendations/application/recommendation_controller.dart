import '../domain/product_recommendation.dart';
import '../domain/recommendation_repository.dart';

/// Application-layer controller for the Smart Recommendation feature.
///
/// The controller acts as the entry point between the presentation layer
/// and the recommendation repository.
///
/// Architecture:
///
/// Presentation
/// → RecommendationController
/// → RecommendationRepository
///
/// It intentionally contains no Firebase-specific logic.
class RecommendationController {
  const RecommendationController({
    required RecommendationRepository recommendationRepository,
  }) : _recommendationRepository = recommendationRepository;

  /// Repository used to obtain personalized recommendations.
  ///
  /// The controller depends on the domain contract instead of a concrete
  /// Firebase implementation, which keeps this layer testable and decoupled
  /// from the backend technology.
  final RecommendationRepository _recommendationRepository;

  /// Returns the personalized product recommendation for the current user.
  ///
  /// A null result is valid and means the backend did not find an eligible
  /// product to recommend.
  Future<ProductRecommendation?> getRecommendation() {
    return _recommendationRepository.getRecommendation();
  }
}