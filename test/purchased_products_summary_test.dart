import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/purchased_products_summary.dart';

Product product(
  String id,
  String category,
  DateTime? date, {
  bool purchased = true,
}) => Product(
  id: id,
  ownerId: 'owner',
  wishlistId: 'wishlist',
  categoryId: category,
  name: id,
  brand: '',
  price: 0,
  imageUrl: '',
  productUrl: '',
  purchased: purchased,
  purchasedAt: date,
);

void main() {
  test('groups purchases by category and calendar month across years', () {
    final summary = PurchasedProductsSummary.fromProducts(
      products: [
        product('one', 'z', DateTime(2025, 12, 1)),
        product('two', 'a', DateTime(2026, 1, 2)),
        product('three', 'z', DateTime(2026, 1, 31)),
        product('four', 'a', DateTime(2026, 2, 1)),
        product('unsaved', 'a', DateTime(2026, 2, 1), purchased: false),
        product('no date', 'a', null),
        product('outside', 'a', DateTime(2025, 11, 30)),
        product('future', 'a', DateTime(2026, 3, 1)),
      ],
      now: DateTime(2026, 2, 15),
      windowMonths: 3,
    );

    expect(summary.months.map((month) => [month.year, month.month]), [
      [2025, 12],
      [2026, 1],
      [2026, 2],
    ]);
    expect(summary.categories.map((category) => category.categoryId), [
      'a',
      'z',
    ]);
    expect(summary.categories[0].monthlyCounts, [0, 1, 1]);
    expect(summary.categories[1].monthlyCounts, [1, 1, 0]);
    expect(summary.monthlyTotals, [1, 2, 1]);
    expect(summary.currentMonthCount, 1);
    expect(summary.previousMonthCount, 2);
    expect(summary.chartMaximum, 3);
  });

  test('empty period gives zero totals and a usable chart scale', () {
    final summary = PurchasedProductsSummary.fromProducts(
      products: [],
      now: DateTime(2026, 2, 15),
      windowMonths: 6,
    );

    expect(summary.categories, isEmpty);
    expect(summary.monthlyTotals, everyElement(0));
    expect(summary.currentMonthCount, 0);
    expect(summary.previousMonthCount, 0);
    expect(summary.chartMaximum, 3);
  });

  test('chart maximum rounds the peak up to the next multiple of three', () {
    final summary = PurchasedProductsSummary.fromProducts(
      products: List.generate(
        4,
        (index) => product('$index', 'a', DateTime(2026, 2, 1)),
      ),
      now: DateTime(2026, 2, 15),
      windowMonths: 2,
    );
    expect(summary.chartMaximum, 6);
  });
}
