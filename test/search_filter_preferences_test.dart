import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whynot_mobile/infrastructure/repositories/search_filter_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores all filters from another store instance', () async {
    final store = SearchFilterPreferences();
    const filters = SearchFilterValues(
      query: 'AirPods',
      category: 'technology',
      minPrice: '100',
      maxPrice: '300',
    );
    await store.save('a', filters);
    final restored = await SearchFilterPreferences().load('a');
    expect(restored?.toList(), filters.toList());
  });

  test('accounts have independent preferences', () async {
    final store = SearchFilterPreferences();
    await store.save('a', const SearchFilterValues(query: 'AirPods'));
    expect(await store.load('b'), isNull);
    await store.save('b', const SearchFilterValues(query: 'Dior'));
    expect((await store.load('a'))?.query, 'AirPods');
    expect((await store.load('b'))?.query, 'Dior');
  });

  test('clear filters persists empty values', () async {
    final store = SearchFilterPreferences();
    await store.save('a', const SearchFilterValues(query: 'AirPods'));
    await store.save('a', const SearchFilterValues());
    expect((await store.load('a'))?.toList(), ['', '', '', '']);
  });

  test('rapid saves preserve the last input across instances', () async {
    final a = SearchFilterPreferences();
    final b = SearchFilterPreferences();
    final first = a.save('a', const SearchFilterValues(query: 'Air'));
    final last = b.save('a', const SearchFilterValues(query: 'AirPods'));
    final restored = await a.load('a');
    await Future.wait([first, last]);
    expect(restored?.query, 'AirPods');
  });
}
