import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/recommended_product_saves.dart';
import '../../models/repositories/admin_metrics_repository.dart';

class FirebaseAdminMetricsRepository implements AdminMetricsRepository {
  FirebaseAdminMetricsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<RecommendedProductSaves> watchRecommendedProductSaves() => _firestore
      .collection('productEvents')
      .where('eventType', isEqualTo: 'recommendation_shown')
      .snapshots()
      .map((snapshot) {
        return RecommendedProductSaves.fromEvents(
          snapshot.docs.map((document) => document.data()),
        );
      });
}
