import 'package:cloud_functions/cloud_functions.dart';

import '../domain/product_recommendation.dart';
import '../domain/recommendation_repository.dart';

/// Firebase implementation of [RecommendationRepository].
///
/// This repository is responsible for communicating with the
/// `get_recommendation` Firebase Cloud Function and translating the raw
/// response into a domain-level [ProductRecommendation].
///
/// Firebase-specific details remain in the data layer so widgets and
/// controllers do not need to know how the backend request is performed.
///
/// The Firebase emulator configuration is intentionally not handled here.
/// During local development, Firebase services are redirected to the Emulator
/// Suite from `main.dart`.
class FirebaseRecommendationRepository implements RecommendationRepository {
  FirebaseRecommendationRepository({
    FirebaseFunctions? functions,
  }) : _functions =
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

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    final rawRecommendation = data['recommendation'];

    // A null recommendation is a valid backend response.
    if (rawRecommendation == null) {
      return null;
    }

    final recommendation = Map<String, dynamic>.from(
      rawRecommendation as Map,
    );

    return ProductRecommendation(
      name: recommendation['name'] as String,
      brand: recommendation['brand'] as String,
      price: (recommendation['price'] as num).toDouble(),
      imageUrl: recommendation['imageUrl'] as String,
      productUrl: recommendation['productUrl'] as String,
      categoryId: recommendation['categoryId'] as String,
      reason: recommendation['reason'] as String,
    );
  }
}