import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/controllers/recommendation_result_cache.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

ProductRecommendation pick(String id) => ProductRecommendation(
  recommendationEventId: id,
  name: id,
  brand: '',
  price: 1,
  imageUrl: '',
  productUrl: '',
  categoryId: 'c',
  reason: '',
);

class CountingRecommendations implements RecommendationRepository {
  final List<Future<ProductRecommendation?> Function()> responses = [];
  int calls = 0;
  int saves = 0;

  @override
  Future<ProductRecommendation?> getRecommendation() {
    calls++;
    return responses.removeAt(0)();
  }

  @override
  Future<void> saveRecommendation({
    required String recommendationEventId,
    required String wishlistId,
  }) async {
    saves++;
  }
}

void main() {
  test(
    'LRU hit, miss, eviction, result and null TTL use controllable time',
    () {
      var now = DateTime.utc(2026, 10, 26);
      final cache = RecommendationResultCache(
        capacity: 2,
        clock: () => now,
        resultTtl: const Duration(minutes: 5),
        emptyTtl: const Duration(seconds: 30),
      );
      expect(cache.lookup('a').$1, false);
      cache.store('a', pick('a'));
      cache.store('b', pick('b'));
      expect(cache.lookup('a').$2?.name, 'a'); // a becomes newest.
      cache.store('c', pick('c')); // b is evicted.
      expect(cache.lookup('b').$1, false);
      expect(cache.lookup('a').$1, true);
      now = now.add(const Duration(minutes: 5));
      expect(cache.lookup('a').$1, false);
      cache.store('empty', null);
      expect(cache.lookup('empty').$1, true);
      now = now.add(const Duration(seconds: 30));
      expect(cache.lookup('empty').$1, false);
      expect(cache.stats.hits, 3);
      expect(cache.stats.evictions, 1);
      expect(cache.stats.expirations, 2);
      expect(cache.stats.misses, 4);
    },
  );

  test('cold request, warm hit, concurrent join, and force refresh', () async {
    final auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'a', email: 'a@example.com'),
    );
    final repository = CountingRecommendations();
    final pending = Completer<ProductRecommendation?>();
    repository.responses.addAll([
      () => pending.future,
      () async => pick('new'),
    ]);
    final controller = RecommendationController(
      recommendationRepository: repository,
      authRepository: auth,
    );
    final cold = controller.getRecommendation();
    final joined = controller.getRecommendation();
    expect(repository.calls, 1);
    pending.complete(pick('old'));
    expect((await cold)?.name, 'old');
    expect((await joined)?.name, 'old');
    expect((await controller.getRecommendation())?.name, 'old');
    expect(repository.calls, 1);
    expect(
      (await controller.getRecommendation(forceRefresh: true))?.name,
      'new',
    );
    expect(repository.calls, 2);
    expect(controller.cacheStats.coalesced, 1);
    expect(controller.cacheStats.hits, 1);
    // Runnable cold/warm evidence: the warm path performs zero backend calls.
    // ignore: avoid_print
    print('Recommendation cache demo: cold=1 callable, warm=0 callables.');
  });

  test(
    'switch/sign-out and invalidation reject stale in-flight completion',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@example.com'),
      );
      final repository = CountingRecommendations();
      final pending = Completer<ProductRecommendation?>();
      repository.responses.addAll([
        () => pending.future,
        () async => pick('b'),
        () async => pick('a-again'),
      ]);
      final controller = RecommendationController(
        recommendationRepository: repository,
        authRepository: auth,
      );
      final oldRequest = controller.getRecommendation();
      auth.user = const AuthUser(id: 'b', email: 'b@example.com');
      expect((await controller.getRecommendation())?.name, 'b');
      pending.complete(pick('a'));
      await expectLater(oldRequest, throwsStateError);
      auth.user = const AuthUser(id: 'a', email: 'a@example.com');
      expect((await controller.getRecommendation())?.name, 'a-again');
      expect(repository.calls, 3);
      auth.user = null;
      await expectLater(controller.getRecommendation(), throwsStateError);
      expect(controller.cachedEntryCount, 0);
    },
  );

  test(
    'successful save invalidates; a failed force refresh retains warm value',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@example.com'),
      );
      final repository = CountingRecommendations();
      repository.responses.addAll([
        () async => pick('first'),
        () async => throw StateError('network'),
        () async => pick('second'),
      ]);
      final controller = RecommendationController(
        recommendationRepository: repository,
        authRepository: auth,
      );
      final first = (await controller.getRecommendation())!;
      await expectLater(
        controller.getRecommendation(forceRefresh: true),
        throwsStateError,
      );
      expect(await controller.getRecommendation(), same(first));
      await controller.saveRecommendation(
        recommendation: first,
        wishlistId: 'w',
      );
      expect((await controller.getRecommendation())?.name, 'second');
      expect(repository.calls, 3);
      expect(repository.saves, 1);
      controller.invalidateForUser('a');
      expect(controller.cachedEntryCount, 0);
    },
  );

  test(
    'mutation invalidation prevents a pending result entering cache',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@example.com'),
      );
      final repository = CountingRecommendations();
      final pending = Completer<ProductRecommendation?>();
      repository.responses.addAll([
        () => pending.future,
        () async => pick('fresh'),
      ]);
      final controller = RecommendationController(
        recommendationRepository: repository,
        authRepository: auth,
      );
      final old = controller.getRecommendation();
      controller.invalidateForUser('a');
      pending.complete(pick('stale'));
      await expectLater(old, throwsStateError);
      expect((await controller.getRecommendation())?.name, 'fresh');
    },
  );
  test(
    'DI hooks invalidate after product, demographic, and wishlist changes',
    () async {
      final repository = CountingRecommendations();
      repository.responses.addAll([
        () async => pick('one'),
        () async => pick('two'),
        () async => pick('three'),
        () async => pick('four'),
      ]);
      final dependencies = createTestDependencies(
        signedIn: true,
        recommendationRepository: repository,
        profiles: const [
          UserProfile(
            id: 'test-user',
            name: 'Santiago',
            email: 'user@example.com',
            gender: 'male',
            age: 24,
            preferredCategoryId: 'c',
            cityId: 'bogota',
          ),
        ],
      );
      final recommendations = dependencies.recommendationController;
      expect((await recommendations.getRecommendation())?.name, 'one');
      await dependencies.productController.create(
        const ProductDraft(
          wishlistId: 'w',
          categoryId: 'c',
          name: 'New product',
          brand: 'Brand',
          price: 10,
          imageUrl: '',
          productUrl: '',
        ),
      );
      expect((await recommendations.getRecommendation())?.name, 'two');
      await dependencies.profileController.updateCurrentProfile(
        const UserProfileUpdate(
          name: 'Santiago',
          gender: 'male',
          age: 25,
          preferredCategoryId: 'c',
          cityId: 'bogota',
        ),
      );
      expect((await recommendations.getRecommendation())?.name, 'three');
      await dependencies.wishlistController.create(
        categoryId: 'c',
        imageUrl: '',
      );
      expect((await recommendations.getRecommendation())?.name, 'four');
      await dependencies.authController.signOut();
      expect(recommendations.cachedEntryCount, 0);
      expect(repository.calls, 4);
    },
  );
}
