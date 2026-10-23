import 'dart:async';

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
  }) async {
    final ownerId = currentUserId;
    if (ownerId == null) throw StateError('No user logged in.');
    try {
      InputPolicy.optionalWebUrl(imageUrl, 'Picture link');
      if (emoji != null && !WishlistEmoji.choices.contains(emoji)) {
        throw const InputPolicyException('Choose an emoji from the list.');
      }
      return await _wishlistRepository.create(
        ownerId: ownerId,
        categoryId: categoryId,
        imageUrl: imageUrl,
        emoji: emoji,
      );
    } on InputPolicyException {
      unawaited(
        _track('create', 'failure', 'validation', categoryId: categoryId),
      );
      rethrow;
    }
  }

  Future<void> updatePresentation({
    required String wishlistId,
    required String imageUrl,
    String? emoji,
  }) async {
    final ownerId = currentUserId;
    if (ownerId == null) throw StateError('No user logged in.');
    try {
      InputPolicy.optionalWebUrl(imageUrl, 'Picture link');
      if (emoji != null && !WishlistEmoji.choices.contains(emoji)) {
        throw const InputPolicyException('Choose an emoji from the list.');
      }
      await _wishlistRepository.updatePresentation(
        ownerId: ownerId,
        wishlistId: wishlistId,
        imageUrl: imageUrl,
        emoji: emoji,
      );
    } on InputPolicyException {
      unawaited(
        _track('edit', 'failure', 'validation', wishlistId: wishlistId),
      );
      rethrow;
    }
  }

  Future<({String outcome, String reason})> deleteEmpty(
    String wishlistId,
  ) async {
    final ownerId = currentUserId;
    if (ownerId == null) throw StateError('No user logged in.');
    return _wishlistRepository.deleteEmpty(
      ownerId: ownerId,
      wishlistId: wishlistId,
    );
  }

  Future<void> _track(
    String action,
    String outcome,
    String reason, {
    String? wishlistId,
    String? categoryId,
  }) async {
    final ownerId = currentUserId;
    if (ownerId == null) return;
    try {
      await _wishlistRepository.trackInteraction(
        ownerId: ownerId,
        action: action,
        outcome: outcome,
        reason: reason,
        wishlistId: wishlistId,
        categoryId: categoryId,
      );
    } catch (_) {
      /* Telemetry must not interrupt the interaction. */
    }
  }

  void trackIntent(String action, {String? wishlistId, String? categoryId}) {
    unawaited(
      _track(
        action,
        'intent',
        'none',
        wishlistId: wishlistId,
        categoryId: categoryId,
      ),
    );
  }
}
