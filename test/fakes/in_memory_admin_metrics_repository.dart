import 'package:whynot_mobile/features/admin/domain/admin_metrics_repository.dart';
import 'package:whynot_mobile/features/admin/domain/recommended_product_saves.dart';

class InMemoryAdminMetricsRepository implements AdminMetricsRepository {
  InMemoryAdminMetricsRepository({this.total = 0});

  final int total;

  @override
  Stream<RecommendedProductSaves> watchRecommendedProductSaves() =>
      Stream.value(RecommendedProductSaves(total: total));
}
