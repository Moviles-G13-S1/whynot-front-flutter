import '../models/product_recommendation.dart';
import '../models/repositories/recommendation_repository.dart';

/// Controller for personalized product recommendations.
///
/// The controller acts as the entry point between views
/// and the recommendation repository.
///
/// Architecture:
///
/// View
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
  /// The controller depends on the repository contract instead of a concrete
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

  Future<void> recordHomeCardEvent({
    required String impressionId,
    required String recommendationEventId,
    required String eventType,
  }) => _recommendationRepository.recordHomeCardEvent(
    impressionId: impressionId,
    recommendationEventId: recommendationEventId,
    eventType: eventType,
  );

  Future<void> saveRecommendation({
    required ProductRecommendation recommendation,
    required String wishlistId,
  }) {
    return _recommendationRepository.saveRecommendation(
      recommendationEventId: recommendation.recommendationEventId,
      wishlistId: wishlistId,
    );
  }
}
