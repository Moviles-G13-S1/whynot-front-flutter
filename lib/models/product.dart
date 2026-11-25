class Product {
  const Product({
    required this.id,
    required this.ownerId,
    required this.wishlistId,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.productUrl,
    required this.purchased,
    this.purchasedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String wishlistId;
  final String categoryId;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final String productUrl;
  final bool purchased;
  final DateTime? purchasedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ProductDraft {
  const ProductDraft({
    required this.wishlistId,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.productUrl,
  });

  final String wishlistId;
  final String categoryId;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final String productUrl;
}

/// Santiago Casasbuenas: One user's products plus the query's cache state.
///
/// The flags belong to the whole query, so an empty list still says whether
/// it came from the device cache or from the server.
class OwnerProducts {
  const OwnerProducts({
    required this.products,
    this.fromCache = false,
    this.hasPendingWrites = false,
  });

  final List<Product> products;

  /// Firestore answered from its offline cache, not the server.
  final bool fromCache;

  /// Some local change has not reached the server yet.
  final bool hasPendingWrites;
}
