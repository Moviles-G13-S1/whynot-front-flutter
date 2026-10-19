abstract final class CategoryCatalog {
  static const labelsById = <String, String>{
    'fashion': 'Fashion',
    'beauty': 'Beauty',
    'technology': 'Technology',
    'home': 'Home',
    'accessories': 'Accessories',
    'travel': 'Travel',
    'gifts': 'Gifts',
    'other': 'Other',
  };

  static final idsByLabel = {
    for (final entry in labelsById.entries) entry.value: entry.key,
  };
}
