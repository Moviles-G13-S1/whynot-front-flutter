import 'recommended_product_saves.dart';

abstract interface class AdminMetricsRepository {
  Stream<RecommendedProductSaves> watchRecommendedProductSaves();
}
