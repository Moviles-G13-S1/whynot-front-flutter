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
