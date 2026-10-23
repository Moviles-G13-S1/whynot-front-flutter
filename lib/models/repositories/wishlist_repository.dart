import '../category.dart';
import '../wishlist.dart';

abstract interface class WishlistRepository {
  Stream<List<Wishlist>> watchByOwner(String ownerId);
  Future<List<Wishlist>> getByOwner(String ownerId);
  Future<List<Category>> getCategories();
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
    String? emoji,
  });
  Future<void> updatePresentation({
    required String ownerId,
    required String wishlistId,
    required String imageUrl,
    String? emoji,
  });

  /// Returns success, blocked/nonempty, or failure/not_found.
  Future<({String outcome, String reason})> deleteEmpty({
    required String ownerId,
    required String wishlistId,
  });
  Future<void> trackInteraction({
    required String ownerId,
    required String action,
    required String outcome,
    required String reason,
    String? wishlistId,
    String? categoryId,
  });
}
