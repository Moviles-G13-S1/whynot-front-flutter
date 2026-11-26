import 'product.dart';

/// Santiago Casasbuenas: Sprint 4 "Stores" view.
///
/// A product has no store field; its store is the registrable domain of its
/// optional product link. The rule matches the backend `store_domains` BQ so
/// the app and the admin dashboard attribute links to the same stores.

/// Second-level suffixes under which the registrable domain has three labels.
const _multiLabelSuffixes = {
  'com.co', 'net.co', 'org.co', 'edu.co', 'gov.co', //
  'com.mx', 'com.ar', 'com.br', 'com.pe', 'com.ec', 'com.uy', 'com.ve',
  'co.uk', 'org.uk', 'co.jp', 'com.au', 'com.es', 'com.cn',
};

/// Returns the registrable domain of a product link, or null if unusable.
String? normalizeStoreDomain(String? url) {
  final text = url?.trim() ?? '';
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // "user@host" is not a product page (it is how "mailto:x@store.com" parses).
  if (uri.userInfo.isNotEmpty) return null;

  var host = uri.host.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  final labels = host.split('.');
  if (labels.length < 2 || labels.any((label) => label.isEmpty)) return null;
  // IP addresses and hosts without a real top-level domain are not stores.
  final topLevel = labels.last;
  if (labels.every((label) => int.tryParse(label) != null) ||
      !RegExp(r'^[a-z]+$').hasMatch(topLevel)) {
    return null;
  }

  final take =
      labels.length >= 3 &&
          _multiLabelSuffixes.contains(
            labels.sublist(labels.length - 2).join('.'),
          )
      ? 3
      : 2;
  return labels.sublist(labels.length - take).join('.');
}

/// A readable store name for a domain.
///
/// A brand is used only when it is the store itself (`goldengoose.com` and
/// "Golden Goose"); resellers such as `cettire.com` keep their own name even if
/// every product there has the same brand.
String storeNameFor(String domain, Iterable<String> brands) {
  final label = domain.split('.').first;
  String compact(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final spellings = <String, int>{};
  for (final brand in brands) {
    final name = brand.trim();
    if (name.isNotEmpty && compact(name) == compact(label)) {
      spellings[name] = (spellings[name] ?? 0) + 1;
    }
  }
  if (spellings.isNotEmpty) {
    // Most common spelling; map order sends ties to the first one seen.
    return spellings.entries
        .reduce((best, next) => next.value > best.value ? next : best)
        .key;
  }
  return label
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// The display fields of one saved product inside a store group.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.purchased,
  });

  factory StoreProduct.fromJson(Map<String, Object?> json) => StoreProduct(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    brand: json['brand'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    imageUrl: json['imageUrl'] as String? ?? '',
    purchased: json['purchased'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final bool purchased;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'price': price,
    'imageUrl': imageUrl,
    'purchased': purchased,
  };
}

/// All of the user's saved products whose link points to one store.
class StoreGroup {
  const StoreGroup({
    required this.domain,
    required this.name,
    required this.products,
  });

  factory StoreGroup.fromJson(Map<String, Object?> json) => StoreGroup(
    domain: json['domain'] as String? ?? '',
    name: json['name'] as String? ?? '',
    products: [
      for (final item in json['products'] as List? ?? const [])
        StoreProduct.fromJson(Map<String, Object?>.from(item as Map)),
    ],
  );

  final String domain;
  final String name;
  final List<StoreProduct> products;

  int get productCount => products.length;
  int get purchasedCount => products.where((item) => item.purchased).length;

  /// Value of the products still pending purchase.
  double get pendingValue => products
      .where((item) => !item.purchased)
      .fold(0, (sum, item) => sum + item.price);

  Map<String, Object?> toJson() => {
    'domain': domain,
    'name': name,
    'products': [for (final item in products) item.toJson()],
  };
}

/// The user's saved products grouped by online store.
class StoreSummary {
  const StoreSummary({
    required this.groups,
    required this.totalProducts,
    required this.withoutLink,
    required this.invalidLink,
    required this.computedAt,
  });

  factory StoreSummary.fromJson(Map<String, Object?> json) => StoreSummary(
    groups: [
      for (final item in json['groups'] as List? ?? const [])
        StoreGroup.fromJson(Map<String, Object?>.from(item as Map)),
    ],
    totalProducts: json['totalProducts'] as int? ?? 0,
    withoutLink: json['withoutLink'] as int? ?? 0,
    invalidLink: json['invalidLink'] as int? ?? 0,
    computedAt: DateTime.fromMillisecondsSinceEpoch(
      json['computedAt'] as int? ?? 0,
    ),
  );

  final List<StoreGroup> groups;
  final int totalProducts;
  final int withoutLink;
  final int invalidLink;
  final DateTime computedAt;

  int get linkedProducts => totalProducts - withoutLink - invalidLink;
  int get unattributed => withoutLink + invalidLink;

  Map<String, Object?> toJson() => {
    'groups': [for (final group in groups) group.toJson()],
    'totalProducts': totalProducts,
    'withoutLink': withoutLink,
    'invalidLink': invalidLink,
    'computedAt': computedAt.millisecondsSinceEpoch,
  };
}

/// Input for [groupProductsByStore]; a record can be sent to an isolate.
typedef StoreGroupingInput = ({List<Product> products, DateTime computedAt});

/// Groups products by store domain. Pure and top-level so it can run on a
/// background isolate: URL parsing and sorting stay off the UI thread.
StoreSummary groupProductsByStore(StoreGroupingInput input) {
  final byDomain = <String, List<Product>>{};
  var withoutLink = 0;
  var invalidLink = 0;
  for (final product in input.products) {
    if (product.productUrl.trim().isEmpty) {
      withoutLink++;
      continue;
    }
    final domain = normalizeStoreDomain(product.productUrl);
    if (domain == null) {
      invalidLink++;
      continue;
    }
    byDomain.putIfAbsent(domain, () => []).add(product);
  }

  final groups = [
    for (final MapEntry(key: domain, value: products) in byDomain.entries)
      StoreGroup(
        domain: domain,
        name: storeNameFor(domain, products.map((item) => item.brand)),
        products: [
          for (final item
              in [...products]..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ))
            StoreProduct(
              id: item.id,
              name: item.name,
              brand: item.brand,
              price: item.price,
              imageUrl: item.imageUrl,
              purchased: item.purchased,
            ),
        ],
      ),
  ];
  // Most products first; ties by pending value, then by name.
  groups.sort((a, b) {
    final count = b.productCount.compareTo(a.productCount);
    if (count != 0) return count;
    final value = b.pendingValue.compareTo(a.pendingValue);
    if (value != 0) return value;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return StoreSummary(
    groups: groups,
    totalProducts: input.products.length,
    withoutLink: withoutLink,
    invalidLink: invalidLink,
    computedAt: input.computedAt,
  );
}

/// The store's logo (its site icon), or a 404 when the store has none.
///
/// Only the store domain is sent; product links and user data never are.
Uri storeLogoUrl(String domain) => Uri.https('www.google.com', '/s2/favicons', {
  'domain': domain,
  'sz': '128',
});
