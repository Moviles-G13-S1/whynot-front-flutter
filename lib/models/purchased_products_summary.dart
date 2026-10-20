import 'product.dart';

class PurchaseCategorySeries {
  const PurchaseCategorySeries(this.categoryId, this.monthlyCounts);

  final String categoryId;
  final List<int> monthlyCounts;
}

/// Purchase counts for consecutive calendar months, ending in [now]'s month.
class PurchasedProductsSummary {
  const PurchasedProductsSummary({
    required this.months,
    required this.categories,
    required this.monthlyTotals,
    required this.chartMaximum,
  });

  final List<DateTime> months;
  final List<PurchaseCategorySeries> categories;
  final List<int> monthlyTotals;
  final double chartMaximum;

  int get currentMonthCount => monthlyTotals.last;
  int get previousMonthCount => monthlyTotals[monthlyTotals.length - 2];

  factory PurchasedProductsSummary.fromProducts({
    required List<Product> products,
    required DateTime now,
    required int windowMonths,
  }) {
    assert(windowMonths >= 2);
    final months = List.generate(
      windowMonths,
      (index) => DateTime(now.year, now.month - windowMonths + index + 1),
    );
    final counts = <String, List<int>>{};
    final monthlyTotals = List<int>.filled(windowMonths, 0);

    for (final product in products) {
      final date = product.purchasedAt;
      if (!product.purchased || date == null) continue;
      final monthIndex = months.indexWhere(
        (month) => month.year == date.year && month.month == date.month,
      );
      if (monthIndex < 0) continue;
      final categoryCounts = counts.putIfAbsent(
        product.categoryId,
        () => List<int>.filled(windowMonths, 0),
      );
      categoryCounts[monthIndex] += 1;
      monthlyTotals[monthIndex] += 1;
    }

    final categoryIds = counts.keys.toList()..sort();
    final peak = monthlyTotals.fold<int>(
      0,
      (maximum, count) => count > maximum ? count : maximum,
    );
    return PurchasedProductsSummary(
      months: months,
      categories: [
        for (final id in categoryIds) PurchaseCategorySeries(id, counts[id]!),
      ],
      monthlyTotals: monthlyTotals,
      chartMaximum: ((peak + 2) ~/ 3 * 3).clamp(3, 1000000).toDouble(),
    );
  }
}
