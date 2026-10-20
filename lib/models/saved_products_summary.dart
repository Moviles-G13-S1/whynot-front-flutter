import 'product.dart';
import 'user_profile.dart';

/// Distribution of current products across users who have at least one.
class SavedProductsSummary {
  const SavedProductsSummary({
    required this.activeUsers,
    required this.zeroProductUsers,
    required this.totalProducts,
    required this.singleProductUsers,
    required this.multipleProductUsers,
    required this.averagePerActiveUser,
    required this.distributionCounts,
  });

  final int activeUsers;
  final int zeroProductUsers;
  final int totalProducts;
  final int singleProductUsers;
  final int multipleProductUsers;
  final double averagePerActiveUser;

  /// Counts for 1–5, 6–10, 11–20, 21–50, and 51+ products.
  final List<int> distributionCounts;

  double get userCountChartMaximum =>
      ((activeUsers + 2) ~/ 3 * 3).clamp(3, 1000000).toDouble();

  double shareForGroup(int index) =>
      activeUsers == 0 ? 0 : distributionCounts[index] / activeUsers;

  factory SavedProductsSummary.fromData({
    required List<Product> products,
    required List<UserProfile> profiles,
  }) {
    final byOwner = <String, int>{};
    for (final product in products) {
      byOwner[product.ownerId] = (byOwner[product.ownerId] ?? 0) + 1;
    }
    final activeUsers = byOwner.length;
    final singleProductUsers = byOwner.values
        .where((count) => count == 1)
        .length;
    final distributionCounts = List<int>.filled(5, 0);
    for (final count in byOwner.values) {
      final index = count <= 5
          ? 0
          : count <= 10
          ? 1
          : count <= 20
          ? 2
          : count <= 50
          ? 3
          : 4;
      distributionCounts[index] += 1;
    }

    return SavedProductsSummary(
      activeUsers: activeUsers,
      zeroProductUsers: profiles
          .where((profile) => !byOwner.containsKey(profile.id))
          .length,
      totalProducts: products.length,
      singleProductUsers: singleProductUsers,
      multipleProductUsers: activeUsers - singleProductUsers,
      averagePerActiveUser: activeUsers == 0
          ? 0
          : products.length / activeUsers,
      distributionCounts: distributionCounts,
    );
  }
}
