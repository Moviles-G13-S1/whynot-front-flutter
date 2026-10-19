class Wishlist {
  const Wishlist({
    required this.id,
    required this.ownerId,
    required this.categoryId,
    required this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String categoryId;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class WishlistSummary {
  const WishlistSummary({required this.wishlist, required this.categoryName});

  final Wishlist wishlist;
  final String categoryName;
}
