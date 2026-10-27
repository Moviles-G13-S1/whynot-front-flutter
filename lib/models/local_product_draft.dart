/// A product form saved locally before submission to Firestore.
///
/// All text fields are stored exactly as entered, including an incomplete
/// price. This is intentionally different from ProductDraft, which requires
/// a valid numeric price.
class LocalProductDraft {
  const LocalProductDraft({
    required this.userId,
    this.wishlistId,
    this.categoryId,
    this.wishlistName,
    this.wishlistEmoji,
    this.name = '',
    this.brand = '',
    this.priceText = '',
    this.imageUrl = '',
    this.productUrl = '',
  });

  final String userId;

  // Selected wishlist, if any.
  final String? wishlistId;
  final String? categoryId;
  final String? wishlistName;
  final String? wishlistEmoji;

  // Raw form values.
  final String name;
  final String brand;
  final String priceText;
  final String imageUrl;
  final String productUrl;
}