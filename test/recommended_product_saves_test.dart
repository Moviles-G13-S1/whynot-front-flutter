import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/models/recommended_product_saves.dart';

void main() {
  test('counts only successful recommendation events', () {
    final result = RecommendedProductSaves.fromEvents([
      {
        'eventType': 'recommendation_shown',
        'savedAt': DateTime.utc(2026, 10, 20),
        'savedProductId': 'product-that-may-now-be-deleted',
      },
      {'eventType': 'recommendation_shown', 'savedAt': null},
      {
        'eventType': 'recommendation_shown',
        'savedAt': DateTime.utc(2026),
        'savedProductId': '',
      },
      {
        'eventType': 'manual_save',
        'savedAt': DateTime.utc(2026),
        'savedProductId': 'other',
      },
    ]);

    expect(result.total, 1);
  });
}
