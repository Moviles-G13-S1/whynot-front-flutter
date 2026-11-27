import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-secret UI preferences, isolated by account.
class SearchFilterValues {
  const SearchFilterValues({
    this.query = '',
    this.category = '',
    this.minPrice = '',
    this.maxPrice = '',
  });

  final String query;
  final String category;
  final String minPrice;
  final String maxPrice;

  List<String> toList() => [query, category, minPrice, maxPrice];
}

class SearchFilterPreferences {
  // Serialize writes across screen instances, including rapid navigation.
  static Future<void> _writes = Future<void>.value();

  String _key(String owner) {
    if (owner.trim().isEmpty) throw ArgumentError('An owner is required.');
    return 'whynot.search.filters.v1.$owner';
  }

  Future<void> save(String owner, SearchFilterValues values) {
    final key = _key(owner);
    final payload = values.toList();
    final operation = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(key, payload)) {
        throw StateError('Could not save search preferences.');
      }
    });
    // A failed write must not poison subsequent writes.
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<SearchFilterValues?> load(String owner) async {
    final key = _key(owner);
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getStringList(key);
    if (raw == null || raw.length != 4) return null;
    return SearchFilterValues(
      query: raw[0],
      category: raw[1],
      minPrice: raw[2],
      maxPrice: raw[3],
    );
  }
}
