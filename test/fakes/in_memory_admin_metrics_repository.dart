import 'package:whynot_mobile/models/repositories/admin_metrics_repository.dart';
import 'package:whynot_mobile/models/recommended_product_saves.dart';

class InMemoryAdminMetricsRepository implements AdminMetricsRepository {
  InMemoryAdminMetricsRepository({this.total = 0});

  final int total;

  @override
  Stream<RecommendedProductSaves> watchRecommendedProductSaves() =>
      Stream.value(RecommendedProductSaves(total: total));
}
