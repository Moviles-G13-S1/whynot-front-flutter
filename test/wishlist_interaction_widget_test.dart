import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/screens/new_wishlist_screen.dart';
import 'package:whynot_mobile/views/screens/wishlist_detail_screen.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

void main() {
  testWidgets('create disables a second submission while saving', (
    tester,
  ) async {
    final repo = _DelayedWishlistRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      wishlistRepositoryOverride: repo,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          routes: {
            AppRoutes.wishlistDetail: (_) =>
                const Scaffold(body: Text('Created')),
          },
          home: const NewWishlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fashion').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repo.createCalls, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Saving...'))
          .onPressed,
      isNull,
    );
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('Created'), findsOneWidget);
    expect(repo.createCalls, 1);
  });
  testWidgets(
    'create form tracks one open, no rebuild, and one explicit cancel',
    (tester) async {
      final repo = InMemoryWishlistRepository(
        categories: const [Category(id: 'fashion', name: 'Fashion')],
      );
      final dependencies = createTestDependencies(
        signedIn: true,
        wishlistRepositoryOverride: repo,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            routes: {
              AppRoutes.wishlists: (_) =>
                  const Scaffold(body: Text('Wishlists')),
              AppRoutes.home: (_) => const Scaffold(body: Text('Home')),
            },
            home: const NewWishlistScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        repo.interactions.where((event) => event.action == 'create_form_open'),
        hasLength(1),
      );
      await tester.pump();
      expect(
        repo.interactions.where((event) => event.action == 'create_form_open'),
        hasLength(1),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        repo.interactions.where(
          (event) => event.action == 'create_form_cancel',
        ),
        hasLength(1),
      );
      expect(find.text('Wishlists'), findsWidgets);
    },
  );

  testWidgets(
    'confirmed nonempty delete stays on detail; empty delete navigates away',
    (tester) async {
      final repo = InMemoryWishlistRepository(
        categories: const [Category(id: 'fashion', name: 'Fashion')],
        wishlists: const [
          Wishlist(
            id: 'w1',
            ownerId: 'test-user',
            categoryId: 'fashion',
            imageUrl: '',
          ),
        ],
      );
      repo.productCounts['w1'] = 1;
      final dependencies = createTestDependencies(
        signedIn: true,
        wishlistRepositoryOverride: repo,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            routes: {
              AppRoutes.wishlists: (_) =>
                  const Scaffold(body: Text('Wishlists')),
            },
            onGenerateInitialRoutes: (_) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(
                  arguments: {
                    'wishlistId': 'w1',
                    'categoryId': 'fashion',
                    'categoryName': 'Fashion',
                  },
                ),
                builder: (_) => const WishlistDetailScreen(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete wishlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Remove the products before deleting this wishlist.'),
        findsOneWidget,
      );
      expect(
        repo.interactions
            .where((event) => event.action == 'delete')
            .single
            .outcome,
        'blocked',
      );
      repo.productCounts['w1'] = 0;
      await tester.tap(find.text('Delete wishlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Wishlists'), findsWidgets);
      expect(
        repo.interactions
            .where((event) => event.action == 'delete')
            .last
            .outcome,
        'success',
      );
    },
  );

  testWidgets(
    'edit dialog updates emoji and detail without changing identity',
    (tester) async {
      final repo = InMemoryWishlistRepository(
        categories: const [Category(id: 'fashion', name: 'Fashion')],
        wishlists: const [
          Wishlist(
            id: 'w1',
            ownerId: 'test-user',
            categoryId: 'fashion',
            imageUrl: '',
          ),
        ],
      );
      final dependencies = createTestDependencies(
        signedIn: true,
        wishlistRepositoryOverride: repo,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            routes: {
              AppRoutes.wishlists: (_) =>
                  const Scaffold(body: Text('Wishlists')),
            },
            onGenerateInitialRoutes: (_) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(
                  arguments: {
                    'wishlistId': 'w1',
                    'categoryId': 'fashion',
                    'categoryName': 'Fashion',
                  },
                ),
                builder: (_) => const WishlistDetailScreen(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit picture & emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎁'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await repo.getByOwner('test-user')).single.emoji, '🎁');
      expect(find.text('🎁'), findsOneWidget);
      expect(
        repo.interactions
            .where((event) => event.action == 'edit')
            .single
            .outcome,
        'success',
      );
    },
  );
}

class _DelayedWishlistRepository extends InMemoryWishlistRepository {
  _DelayedWishlistRepository()
    : super(
        categories: const [Category(id: 'fashion', name: 'Fashion')],
      );
  final release = Completer<void>();
  int createCalls = 0;

  @override
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
    String? emoji,
  }) async {
    createCalls++;
    await release.future;
    return super.create(
      ownerId: ownerId,
      categoryId: categoryId,
      imageUrl: imageUrl,
      emoji: emoji,
    );
  }
}
