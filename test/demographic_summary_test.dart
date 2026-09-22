import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/features/admin/domain/demographic_summary.dart';
import 'package:whynot_mobile/features/products/domain/product.dart';
import 'package:whynot_mobile/features/profile/domain/user_profile.dart';
import 'package:whynot_mobile/shared/domain/city.dart';

void main() {
  test('counts unique owners with an existing product in the category', () {
    final summary = DemographicSummary.fromData(
      categoryId: 'technology',
      products: const [
        Product(
          id: 'one',
          ownerId: 'alice',
          wishlistId: 'a',
          categoryId: 'technology',
          name: 'Phone',
          brand: 'Brand',
          price: 1,
          imageUrl: '',
          productUrl: '',
          purchased: false,
        ),
        Product(
          id: 'two',
          ownerId: 'alice',
          wishlistId: 'a',
          categoryId: 'technology',
          name: 'Laptop',
          brand: 'Brand',
          price: 1,
          imageUrl: '',
          productUrl: '',
          purchased: false,
        ),
        Product(
          id: 'three',
          ownerId: 'bob',
          wishlistId: 'b',
          categoryId: 'technology',
          name: 'Tablet',
          brand: 'Brand',
          price: 1,
          imageUrl: '',
          productUrl: '',
          purchased: false,
        ),
        Product(
          id: 'four',
          ownerId: 'carol',
          wishlistId: 'c',
          categoryId: 'beauty',
          name: 'Cream',
          brand: 'Brand',
          price: 1,
          imageUrl: '',
          productUrl: '',
          purchased: false,
        ),
      ],
      profiles: const [
        UserProfile(
          id: 'alice',
          name: 'Alice',
          email: 'a@example.com',
          gender: 'Female',
          age: 22,
          preferredCategoryId: 'beauty',
          cityId: 'bogota',
        ),
        UserProfile(
          id: 'bob',
          name: 'Bob',
          email: 'b@example.com',
          gender: 'Male',
          age: 32,
          preferredCategoryId: 'technology',
        ),
        UserProfile(
          id: 'carol',
          name: 'Carol',
          email: 'c@example.com',
          gender: 'Female',
          age: 40,
          preferredCategoryId: 'beauty',
          cityId: 'bogota',
        ),
      ],
      cityCatalog: const [City(id: 'bogota', name: 'Bogotá')],
    );

    expect(summary.userCount, 2);
    expect(summary.medianAge, '27');
    expect(summary.ages[1].count, 1);
    expect(summary.ages[2].count, 1);
    expect(summary.genders[0].percent, 50);
    expect(summary.cities[0].label, 'Bogotá');
    expect(summary.cities[0].percent, 50);
    expect(summary.cities.last.label, 'Other / unknown');
    expect(summary.cities.last.percent, 50);
  });

  test('shows zero values when a category has no product owners', () {
    final summary = DemographicSummary.fromData(
      categoryId: 'travel',
      products: const [],
      profiles: const [],
      cityCatalog: const [],
    );
    expect(summary.userCount, 0);
    expect(summary.medianAge, '—');
    expect(summary.ages.every((group) => group.percent == 0), isTrue);
    expect(summary.cities.single.count, 0);
  });
}
