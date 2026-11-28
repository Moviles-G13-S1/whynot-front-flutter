import 'product.dart';

/// Calendar boundaries match the shared project's America/Bogota convention.
DateTime spendingDate(DateTime date) =>
    date.toUtc().subtract(const Duration(hours: 5));

String spendingMonth(DateTime date) {
  final local = spendingDate(date);
  return '${local.year}-${local.month.toString().padLeft(2, '0')}';
}

class SpendingPurchase {
  const SpendingPurchase({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.amountCents,
    this.purchasedAt,
  });
  final String id;
  final String categoryId;
  final String name;
  final String brand;
  final int amountCents;
  final DateTime? purchasedAt;

  static SpendingPurchase? fromProduct(Product product) {
    if (!product.purchased || !product.price.isFinite || product.price < 0) {
      return null;
    }
    return SpendingPurchase(
      id: product.id,
      categoryId: product.categoryId,
      name: product.name,
      brand: product.brand,
      amountCents: (product.price * 100).round(),
      purchasedAt: product.purchasedAt,
    );
  }
}

class SpendingSnapshot {
  SpendingSnapshot({
    required List<SpendingPurchase> purchases,
    required this.syncedAt,
  }) : purchases = List.unmodifiable(purchases);
  final List<SpendingPurchase> purchases;
  final DateTime syncedAt;
}

class SpendingCategory {
  SpendingCategory(this.id, List<SpendingPurchase> products)
    : products = List.unmodifiable(products),
      totalCents = products.fold(0, (sum, p) => sum + p.amountCents);
  final String id;
  final List<SpendingPurchase> products;
  final int totalCents;
}

class MonthlySpending {
  MonthlySpending(this.month, List<SpendingCategory> categories)
    : categories = List.unmodifiable(categories),
      totalCents = categories.fold(0, (sum, c) => sum + c.totalCents),
      count = categories.fold(0, (sum, c) => sum + c.products.length);
  final String month;
  final List<SpendingCategory> categories;
  final int totalCents;
  final int count;
}

String spendingCategoryName(String id) =>
    const {
      'fashion': 'Fashion',
      'beauty': 'Beauty',
      'technology': 'Technology',
      'home': 'Home',
      'accessories': 'Accessories',
      'travel': 'Travel',
      'gifts': 'Gifts',
      'other': 'Other',
    }[id] ??
    (id.isEmpty ? 'Uncategorized' : id);
