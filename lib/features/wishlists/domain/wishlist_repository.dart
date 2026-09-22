import '../../../shared/domain/category.dart';
import 'wishlist.dart';

abstract interface class WishlistRepository {
  Stream<List<Wishlist>> watchByOwner(String ownerId);
  Future<List<Wishlist>> getByOwner(String ownerId);
  Future<List<Category>> getCategories();
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
  });
}
