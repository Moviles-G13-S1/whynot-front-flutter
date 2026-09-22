import 'package:whynot_mobile/features/recommendations/domain/product_recommendation.dart';
import 'package:whynot_mobile/features/recommendations/domain/recommendation_repository.dart';

class InMemoryRecommendationRepository implements RecommendationRepository {
  InMemoryRecommendationRepository({this.recommendation});

  final ProductRecommendation? recommendation;

  @override
  Future<ProductRecommendation?> getRecommendation() async {
    return recommendation;
  }
}
