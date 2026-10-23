import '../models/repositories/auth_repository.dart';
import '../models/category.dart';
import '../models/wishlist.dart';
import '../models/wishlist_emoji.dart';
import '../models/input_policy.dart';
import '../models/repositories/wishlist_repository.dart';

class WishlistController {
  const WishlistController({
    required AuthRepository authRepository,
    required WishlistRepository wishlistRepository,
  }) : _authRepository = authRepository,
       _wishlistRepository = wishlistRepository;

  final AuthRepository _authRepository;
  final WishlistRepository _wishlistRepository;

  String? get currentUserId => _authRepository.currentUser?.id;

  Future<List<Category>> getCategories() => _wishlistRepository.getCategories();

  Stream<List<WishlistSummary>> watchCurrentSummaries() async* {
    final ownerId = currentUserId;
    if (ownerId == null) {
      yield const [];
      return;
    }
    final categories = await _wishlistRepository.getCategories();
    final names = {
      for (final category in categories) category.id: category.name,
    };
    yield* _wishlistRepository
        .watchByOwner(ownerId)
        .map(
          (wishlists) => wishlists
              .map(
                (wishlist) => WishlistSummary(
                  wishlist: wishlist,
                  categoryName:
                      names[wishlist.categoryId] ?? wishlist.categoryId,
                ),
              )
              .toList(),
        );
  }

  Future<List<WishlistSummary>> getCurrentSummaries() async {
    final ownerId = currentUserId;
    if (ownerId == null) return const [];
    final categoriesFuture = _wishlistRepository.getCategories();
    final wishlistsFuture = _wishlistRepository.getByOwner(ownerId);
    final categories = await categoriesFuture;
    final wishlists = await wishlistsFuture;
    final names = {
      for (final category in categories) category.id: category.name,
    };
    final summaries = wishlists
        .map(
          (wishlist) => WishlistSummary(
            wishlist: wishlist,
            categoryName: names[wishlist.categoryId] ?? wishlist.categoryId,
          ),
        )
        .toList();
    summaries.sort((a, b) => a.categoryName.compareTo(b.categoryName));
    return summaries;
  }

  Future<List<MapEntry<String, String>>> getAvailableCategories() async {
    final ownerId = currentUserId;
    if (ownerId == null) return const [];
    final categories = await _wishlistRepository.getCategories();
    final wishlists = await _wishlistRepository.getByOwner(ownerId);
    final used = wishlists.map((wishlist) => wishlist.categoryId).toSet();
    final available = categories
        .where((category) => !used.contains(category.id))
        .map((category) => MapEntry(category.id, category.name))
        .toList();
    available.sort((a, b) => a.value.compareTo(b.value));
    return available;
  }

  Future<String> create({
    required String categoryId,
    required String imageUrl,
    String? emoji,
  }) {
    final ownerId = currentUserId;
    if (ownerId == null) throw StateError('No user logged in.');
    InputPolicy.optionalWebUrl(imageUrl, 'Picture link');
    if (emoji != null && !WishlistEmoji.choices.contains(emoji)) {
      throw const InputPolicyException('Choose an emoji from the list.');
    }
    return _wishlistRepository.create(
      ownerId: ownerId,
      categoryId: categoryId,
      imageUrl: imageUrl,
      emoji: emoji,
    );
  }
}
