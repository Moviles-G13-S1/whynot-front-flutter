import '../../products/domain/product.dart';
import '../../profile/domain/user_profile.dart';
import '../../../shared/domain/city.dart';

class DemographicGroup {
  const DemographicGroup(this.label, this.count, this.total);

  final String label;
  final int count;
  final int total;

  int get percent => total == 0 ? 0 : (count * 100 / total).round();
}

class DemographicSummary {
  const DemographicSummary({
    required this.userCount,
    required this.medianAge,
    required this.ages,
    required this.genders,
    required this.cities,
  });

  final int userCount;
  final String medianAge;
  final List<DemographicGroup> ages;
  final List<DemographicGroup> genders;
  final List<DemographicGroup> cities;

  factory DemographicSummary.fromData({
    required String categoryId,
    required List<Product> products,
    required List<UserProfile> profiles,
    required List<City> cityCatalog,
  }) {
    final ownerIds = products
        .where((product) => product.categoryId == categoryId)
        .map((product) => product.ownerId)
        .toSet();
    final users = profiles
        .where((profile) => ownerIds.contains(profile.id))
        .toList();
    final total = users.length;

    final sortedAges = users.map((user) => user.age).toList()..sort();
    final medianAge = sortedAges.isEmpty
        ? '—'
        : sortedAges.length.isOdd
        ? '${sortedAges[sortedAges.length ~/ 2]}'
        : ((sortedAges[sortedAges.length ~/ 2 - 1] +
                      sortedAges[sortedAges.length ~/ 2]) /
                  2)
              .toStringAsFixed(1)
              .replaceAll(RegExp(r'\.0$'), '');

    final ageCounts = List.filled(6, 0);
    final genderCounts = <String, int>{'Female': 0, 'Male': 0, 'Other': 0};
    final cityCounts = <String, int>{};
    for (final user in users) {
      final ageIndex = user.age <= 17
          ? 0
          : user.age <= 24
          ? 1
          : user.age <= 34
          ? 2
          : user.age <= 44
          ? 3
          : user.age <= 54
          ? 4
          : 5;
      ageCounts[ageIndex]++;
      genderCounts[user.gender] = (genderCounts[user.gender] ?? 0) + 1;
      final cityId = user.cityId ?? 'other';
      cityCounts[cityId] = (cityCounts[cityId] ?? 0) + 1;
    }

    final cityNames = {for (final city in cityCatalog) city.id: city.name};
    final mainCities =
        cityCounts.entries
            .where(
              (entry) =>
                  entry.key != 'other' && cityNames.containsKey(entry.key),
            )
            .toList()
          ..sort((a, b) {
            final countOrder = b.value.compareTo(a.value);
            return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
          });
    final topCities = mainCities.take(4).toList();
    final otherCount =
        total - topCities.fold<int>(0, (sum, city) => sum + city.value);

    return DemographicSummary(
      userCount: total,
      medianAge: medianAge,
      ages: [
        for (var index = 0; index < ageCounts.length; index++)
          DemographicGroup(
            const ['13–17', '18–24', '25–34', '35–44', '45–54', '55+'][index],
            ageCounts[index],
            total,
          ),
      ],
      genders: [
        DemographicGroup('Women', genderCounts['Female'] ?? 0, total),
        DemographicGroup('Men', genderCounts['Male'] ?? 0, total),
        DemographicGroup('Other', genderCounts['Other'] ?? 0, total),
      ],
      cities: [
        for (final city in topCities)
          DemographicGroup(cityNames[city.key]!, city.value, total),
        DemographicGroup('Other / unknown', otherCount, total),
      ],
    );
  }
}
