import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';

class InMemoryRecommendationRepository implements RecommendationRepository {
  InMemoryRecommendationRepository({this.recommendation});

  final ProductRecommendation? recommendation;
  final saves = <({String recommendationEventId, String wishlistId})>[];
  final homeEvents =
      <
        ({String impressionId, String recommendationEventId, String eventType})
      >[];

  @override
  Future<void> recordHomeCardEvent({
    required String impressionId,
    required String recommendationEventId,
    required String eventType,
  }) async {
    homeEvents.add((
      impressionId: impressionId,
      recommendationEventId: recommendationEventId,
      eventType: eventType,
    ));
  }

  @override
  Future<ProductRecommendation?> getRecommendation() async {
    return recommendation;
  }

  @override
  Future<void> saveRecommendation({
    required String recommendationEventId,
    required String wishlistId,
  }) async {
    saves.add((
      recommendationEventId: recommendationEventId,
      wishlistId: wishlistId,
    ));
  }
}
