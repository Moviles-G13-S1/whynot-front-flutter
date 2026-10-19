import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';

class InMemoryRecommendationRepository implements RecommendationRepository {
  InMemoryRecommendationRepository({this.recommendation});

  final ProductRecommendation? recommendation;

  @override
  Future<ProductRecommendation?> getRecommendation() async {
    return recommendation;
  }
}
