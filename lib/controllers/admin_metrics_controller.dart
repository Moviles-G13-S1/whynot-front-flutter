import '../models/repositories/admin_metrics_repository.dart';
import '../models/recommended_product_saves.dart';

class AdminMetricsController {
  const AdminMetricsController(this._repository);

  final AdminMetricsRepository _repository;

  Stream<RecommendedProductSaves> watchRecommendedProductSaves() =>
      _repository.watchRecommendedProductSaves();
}
