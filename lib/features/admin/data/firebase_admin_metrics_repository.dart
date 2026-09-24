import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/admin_metrics_repository.dart';
import '../domain/recommended_product_saves.dart';

class FirebaseAdminMetricsRepository implements AdminMetricsRepository {
  FirebaseAdminMetricsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<RecommendedProductSaves> watchRecommendedProductSaves() => _firestore
      .collection('adminMetrics')
      .doc('recommendedProductSaves')
      .snapshots()
      .map((document) {
        final data = document.data();
        final rawTotal = data?['total'];
        final total = rawTotal is num && rawTotal >= 0 ? rawTotal.toInt() : 0;

        return RecommendedProductSaves(
          total: total,
          updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate(),
        );
      });
}
