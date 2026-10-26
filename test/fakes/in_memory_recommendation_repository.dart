import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/recommendation_catalog_item.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';

class InMemoryRecommendationRepository implements RecommendationRepository {
  InMemoryRecommendationRepository({this.recommendation});

  final ProductRecommendation? recommendation;
  final saves = <({String recommendationEventId, String wishlistId})>[];

  @override
  Future<ProductRecommendation?> getRecommendation() async {
    return recommendation;
  }

  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async => const [];

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async =>
      recommendation ?? (throw StateError('No recommendation available.'));

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
