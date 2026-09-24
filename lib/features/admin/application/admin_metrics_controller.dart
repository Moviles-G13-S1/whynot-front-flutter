import '../domain/admin_metrics_repository.dart';
import '../domain/recommended_product_saves.dart';

class AdminMetricsController {
  const AdminMetricsController(this._repository);

  final AdminMetricsRepository _repository;

  Stream<RecommendedProductSaves> watchRecommendedProductSaves() =>
      _repository.watchRecommendedProductSaves();
}
