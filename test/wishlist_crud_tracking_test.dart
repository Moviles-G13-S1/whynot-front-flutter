import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/wishlist_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/input_policy.dart';
import 'package:whynot_mobile/models/wishlist.dart';

import 'fakes/in_memory_repositories.dart';

void main() {
  late InMemoryWishlistRepository repo;
  late WishlistController controller;
  setUp(() {
    repo = InMemoryWishlistRepository(
      categories: const [Category(id: 'fashion', name: 'Fashion')],
      wishlists: const [
        Wishlist(
          id: 'legacy',
          ownerId: 'alice',
          categoryId: 'fashion',
          imageUrl: '',
        ),
      ],
    );
    controller = WishlistController(
      authRepository: InMemoryAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      ),
      wishlistRepository: repo,
    );
  });

  test(
    'edit changes only presentation and preserves a legacy missing emoji',
    () async {
      final before = (await repo.getByOwner('alice')).single;
      expect(before.emoji, isNull);
      await controller.updatePresentation(
        wishlistId: before.id,
        imageUrl: 'https://example.com/a.png',
        emoji: '🎁',
      );
      final after = (await repo.getByOwner('alice')).single;
      expect(
        (after.id, after.ownerId, after.categoryId),
        (before.id, before.ownerId, before.categoryId),
      );
      expect(
        (after.imageUrl, after.emoji),
        ('https://example.com/a.png', '🎁'),
      );
      expect(repo.interactions.single.action, 'edit');
      expect(repo.interactions.single.outcome, 'success');
    },
  );

  test(
    'invalid presentation fails before update and records a validation outcome',
    () async {
      await expectLater(
        controller.updatePresentation(
          wishlistId: 'legacy',
          imageUrl: 'javascript:bad',
        ),
        throwsA(isA<InputPolicyException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect((await repo.getByOwner('alice')).single.imageUrl, '');
      expect(repo.interactions.single.reason, 'validation');
    },
  );

  test(
    'nonempty deletion is blocked, empty deletion succeeds, and foreign owner cannot edit',
    () async {
      repo.productCounts['legacy'] = 1;
      expect((await controller.deleteEmpty('legacy')).reason, 'nonempty');
      expect(await repo.getByOwner('alice'), hasLength(1));
      repo.productCounts['legacy'] = 0;
      expect((await controller.deleteEmpty('legacy')).outcome, 'success');
      expect(await repo.getByOwner('alice'), isEmpty);
      await expectLater(
        controller.updatePresentation(wishlistId: 'legacy', imageUrl: ''),
        throwsStateError,
      );
      expect(
        repo.interactions
            .where((event) => event.action == 'delete')
            .map((event) => event.outcome),
        ['blocked', 'success'],
      );
    },
  );

  test(
    'read streams and rebuild-equivalent reads emit no interaction',
    () async {
      await controller.watchCurrentSummaries().first;
      await controller.watchCurrentSummaries().first;
      await controller.getCurrentSummaries();
      expect(repo.interactions, isEmpty);
      controller.trackIntent(
        'open',
        wishlistId: 'legacy',
        categoryId: 'fashion',
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.interactions.single.action, 'open');
    },
  );
}
