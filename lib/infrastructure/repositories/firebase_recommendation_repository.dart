import 'package:cloud_functions/cloud_functions.dart';

import '../../models/product_recommendation.dart';
import '../../models/recommendation_catalog_item.dart';
import '../../models/repositories/recommendation_repository.dart';

/// Firebase implementation of [RecommendationRepository].
///
/// This repository is responsible for communicating with the
/// `get_recommendation` Firebase Cloud Function and translating the raw
/// response into a domain-level [ProductRecommendation].
///
/// Firebase-specific details remain in the infrastructure layer so widgets and
/// controllers do not need to know how the backend request is performed.
///
/// The Firebase emulator configuration is intentionally not handled here.
/// During local development, Firebase services are redirected to the Emulator
/// Suite from `main.dart`.
class FirebaseRecommendationRepository implements RecommendationRepository {
  FirebaseRecommendationRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Firebase Functions client used to communicate with the backend.
  ///
  /// A client can optionally be injected, which keeps this repository
  /// testable and independent from the way Firebase is configured at startup.
  final FirebaseFunctions _functions;

  /// Requests the personalized product recommendation for the current user.
  ///
  /// The callable Cloud Function returns an object containing a
  /// `recommendation` field.
  ///
  /// If the field is null, no eligible recommendation was found and this
  /// method returns null. Otherwise, the backend response is converted into
  /// a [ProductRecommendation].
  @override
  Future<ProductRecommendation?> getRecommendation() async {
    final callable = _functions.httpsCallable('get_recommendation');

    final result = await callable.call();

    final data = Map<String, dynamic>.from(result.data as Map);

    final rawRecommendation = data['recommendation'];

    // A null recommendation is a valid backend response.
    if (rawRecommendation == null) {
      return null;
    }

    final recommendation = Map<String, dynamic>.from(rawRecommendation as Map);

    return _parseRecommendation(recommendation);
  }

  ProductRecommendation _parseRecommendation(
    Map<String, dynamic> recommendation,
  ) {
    return ProductRecommendation(
      recommendationEventId: recommendation['recommendationEventId'] as String,
      name: recommendation['name'] as String,
      brand: recommendation['brand'] as String,
      price: (recommendation['price'] as num).toDouble(),
      imageUrl: recommendation['imageUrl'] as String,
      productUrl: recommendation['productUrl'] as String,
      categoryId: recommendation['categoryId'] as String,
      reason: recommendation['reason'] as String,
    );
  }

  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    final result = await _functions
        .httpsCallable('get_recommendation_catalog')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final rawItems = data['recommendations'] as List;
    return rawItems
        .map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return RecommendationCatalogItem(
            sourceProductId: item['sourceProductId'] as String,
            name: item['name'] as String,
            brand: item['brand'] as String,
            price: (item['price'] as num).toDouble(),
            imageUrl: item['imageUrl'] as String,
            categoryId: item['categoryId'] as String,
            reason: item['reason'] as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    final result = await _functions.httpsCallable('get_recommendation').call({
      'sourceProductId': sourceProductId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return _parseRecommendation(
      Map<String, dynamic>.from(data['recommendation'] as Map),
    );
  }

  @override
  Future<void> saveRecommendation({
    required String recommendationEventId,
    required String wishlistId,
  }) async {
    await _functions.httpsCallable('save_recommended_product').call({
      'recommendationEventId': recommendationEventId,
      'wishlistId': wishlistId,
    });
  }
}
