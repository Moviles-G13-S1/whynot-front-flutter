import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/saved_products_summary.dart';
import 'package:whynot_mobile/models/user_profile.dart';

Product product(String owner, int index) => Product(
  id: '$owner-$index',
  ownerId: owner,
  wishlistId: 'wishlist',
  categoryId: 'category',
  name: 'Product',
  brand: '',
  price: 0,
  imageUrl: '',
  productUrl: '',
  purchased: false,
);

UserProfile profile(String id) => UserProfile(
  id: id,
  name: id,
  email: '$id@example.com',
  gender: 'Other',
  age: 20,
  preferredCategoryId: 'category',
);

void main() {
  test(
    'empty products preserve zero averages and count users without products',
    () {
      final summary = SavedProductsSummary.fromData(
        products: [],
        profiles: [profile('one'), profile('two')],
      );

      expect(summary.activeUsers, 0);
      expect(summary.zeroProductUsers, 2);
      expect(summary.totalProducts, 0);
      expect(summary.singleProductUsers, 0);
      expect(summary.multipleProductUsers, 0);
      expect(summary.averagePerActiveUser, 0);
      expect(summary.distributionCounts, [0, 0, 0, 0, 0]);
      expect(summary.shareForGroup(0), 0);
      expect(summary.userCountChartMaximum, 3);
    },
  );

  test('assigns users at each bucket boundary and computes KPIs', () {
    const ownerCounts = [1, 5, 6, 10, 11, 20, 21, 50, 51];
    final products = [
      for (var owner = 0; owner < ownerCounts.length; owner++)
        for (var index = 0; index < ownerCounts[owner]; index++)
          product('owner$owner', index),
    ];
    final summary = SavedProductsSummary.fromData(
      products: products,
      profiles: [profile('owner0'), profile('inactive')],
    );

    expect(summary.activeUsers, 9);
    expect(summary.zeroProductUsers, 1);
    expect(summary.totalProducts, 175);
    expect(summary.singleProductUsers, 1);
    expect(summary.multipleProductUsers, 8);
    expect(summary.averagePerActiveUser, closeTo(175 / 9, 0.00001));
    expect(summary.distributionCounts, [2, 2, 2, 2, 1]);
    expect(summary.shareForGroup(0), closeTo(2 / 9, 0.00001));
    expect(summary.userCountChartMaximum, 9);
  });
}
