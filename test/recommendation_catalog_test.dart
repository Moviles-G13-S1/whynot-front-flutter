import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/controllers/recommendation_catalog_snapshot_cache.dart';
import 'package:whynot_mobile/controllers/recommendation_result_cache.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/catalog_product_details.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/recommendation_catalog_item.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';
import 'package:whynot_mobile/views/screens/recommendation_catalog_screen.dart';
import 'package:whynot_mobile/views/screens/recommendation_detail_screen.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';
import 'fakes/in_memory_repositories.dart';

const catalogItem = RecommendationCatalogItem(
  sourceProductId: 'source-1',
  name: 'Jacket',
  brand: 'Studio',
  price: 20000,
  imageUrl: '',
  categoryId: 'fashion',
  reason: 'A similar user bought this.',
);

const technologyItem = RecommendationCatalogItem(
  sourceProductId: 'source-2',
  name: 'Headphones',
  brand: 'Studio',
  price: 30000,
  imageUrl: '',
  categoryId: 'technology',
  reason: 'A similar user saved this.',
);

class CatalogRepository extends InMemoryRecommendationRepository {
  int catalogCalls = 0;
  int opens = 0;
  int compactOpens = 0;

  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    catalogCalls++;
    return catalogCalls == 1
        ? const [catalogItem]
        : const [catalogItem, technologyItem];
  }

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    opens++;
    expect(sourceProductId, catalogItem.sourceProductId);
    return ProductRecommendation(
      recommendationEventId: 'full-event-$opens',
      name: 'Jacket',
      brand: 'Studio',
      price: 20000,
      imageUrl: '',
      productUrl: '',
      categoryId: 'fashion',
      reason: 'A similar user bought this.',
    );
  }

  @override
  Future<String> createCatalogEvent(String sourceProductId) async {
    compactOpens++;
    expect(sourceProductId, catalogItem.sourceProductId);
    return 'compact-event-$compactOpens';
  }
}

class ManyCatalogRepository extends CatalogRepository {
  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    opens++;
    return ProductRecommendation(
      recommendationEventId: 'full-event-$opens',
      name: sourceProductId,
      brand: 'Studio',
      price: 20000,
      imageUrl: '',
      productUrl: '',
      categoryId: 'fashion',
      reason: 'A similar user saved this.',
    );
  }

  @override
  Future<String> createCatalogEvent(String sourceProductId) async {
    compactOpens++;
    return 'compact-event-$compactOpens';
  }
}

class DeferredRepeatOpenRepository extends CatalogRepository {
  final event = Completer<String>();

  @override
  Future<String> createCatalogEvent(String sourceProductId) {
    compactOpens++;
    return event.future;
  }
}

class UnavailableCatalogRepository extends CatalogRepository {
  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    throw const RecommendationCatalogUnavailable();
  }
}

void main() {
  testWidgets('repeat open shows product while only save waits for event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DeferredRepeatOpenRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.recommendationCatalog,
                ),
                child: const Text('Open catalog'),
              ),
            ),
          ),
          routes: {
            AppRoutes.recommendationCatalog: (_) =>
                const RecommendationCatalogScreen(),
            AppRoutes.recommendationDetail: (_) =>
                const RecommendationDetailScreen(),
          },
        ),
      ),
    );
    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jacket'));
    await tester.pumpAndSettle();
    expect(find.text('Save this product'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jacket'));
    await tester.pumpAndSettle();
    expect(repository.compactOpens, 1);
    expect(find.text('Jacket'), findsOneWidget);
    expect(find.text('Preparing save...'), findsOneWidget);
    expect(find.text('Save this product'), findsNothing);

    repository.event.complete('fresh-event-2');
    await tester.pumpAndSettle();
    expect(find.text('Save this product'), findsOneWidget);
    expect(find.text('Preparing save...'), findsNothing);
  });

  test('empty catalog snapshot expires after 30 seconds', () {
    var now = DateTime.utc(2026, 10, 26);
    final cache = RecommendationCatalogSnapshotCache(clock: () => now);
    cache.store('a', const []);
    expect(cache.lookup('a').$1, true);
    now = now.add(const Duration(seconds: 30));
    expect(cache.lookup('a').$1, false);
  });

  testWidgets('open catalog reloads after a product is saved', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CatalogRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(home: RecommendationCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jacket'), findsOneWidget);
    expect(find.text('Headphones'), findsNothing);
    await dependencies.productController.create(
      const ProductDraft(
        wishlistId: 'wishlist',
        categoryId: 'technology',
        name: 'Phone',
        brand: 'Studio',
        price: 10000,
        imageUrl: '',
        productUrl: '',
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.catalogCalls, 2);
    expect(find.text('Headphones'), findsOneWidget);
    expect(find.text('Fetched fresh catalog'), findsOneWidget);
  });

  testWidgets('missing catalog service has a specific recovery message', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(
          signedIn: true,
          recommendationRepository: UnavailableCatalogRepository(),
        ),
        child: const MaterialApp(home: RecommendationCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Recommendation catalog is not available in this app environment yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  test(
    'catalog TTL, invalidation, and user switch require fresh calls',
    () async {
      var now = DateTime.utc(2026, 10, 26);
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@example.com'),
      );
      final repository = CatalogRepository();
      final controller = RecommendationController(
        recommendationRepository: repository,
        authRepository: auth,
        catalogSnapshotCache: RecommendationCatalogSnapshotCache(
          clock: () => now,
        ),
      );
      expect((await controller.getCatalog()).fromCache, false);
      expect((await controller.getCatalog()).fromCache, true);
      expect(repository.catalogCalls, 1);
      now = now.add(const Duration(minutes: 5));
      expect((await controller.getCatalog()).fromCache, false);
      controller.invalidateForUser('a');
      expect((await controller.getCatalog()).fromCache, false);
      auth.user = const AuthUser(id: 'b', email: 'b@example.com');
      expect((await controller.getCatalog()).fromCache, false);
      expect(repository.catalogCalls, 4);
    },
  );

  test('opened details use five LRU slots and fresh events', () async {
    var now = DateTime.utc(2026, 10, 26);
    final auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'a', email: 'a@example.com'),
    );
    final repository = ManyCatalogRepository();
    final controller = RecommendationController(
      recommendationRepository: repository,
      authRepository: auth,
      catalogProductCache: RecommendationResultCache<CatalogProductDetails>(
        capacity: 5,
        clock: () => now,
      ),
    );
    await controller.getCatalog();
    for (var i = 1; i <= 5; i++) {
      await controller.openCatalogItem('source-$i');
    }
    expect(repository.opens, 5);
    expect(controller.isCatalogProductCached('source-1'), true);
    final reopened = await controller.openCatalogItem('source-1');
    expect(reopened.recommendationEventId, 'compact-event-1');
    expect(repository.opens, 5);
    expect(repository.compactOpens, 1);
    await controller.openCatalogItem('source-6');
    expect(controller.isCatalogProductCached('source-1'), true);
    expect(controller.isCatalogProductCached('source-2'), false);
    expect(controller.isCatalogProductCached('source-6'), true);
    now = now.add(const Duration(minutes: 5));
    expect(controller.isCatalogProductCached('source-1'), false);
    controller.invalidateForUser('a');
    expect(controller.isCatalogProductCached('source-6'), false);
  });

  testWidgets('catalog revisit identifies cached data and refresh fetches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CatalogRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.recommendationCatalog,
                ),
                child: const Text('Open catalog'),
              ),
            ),
          ),
          routes: {
            AppRoutes.recommendationCatalog: (_) =>
                const RecommendationCatalogScreen(),
            AppRoutes.recommendationDetail: (_) =>
                const RecommendationDetailScreen(),
          },
        ),
      ),
    );
    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Fetched fresh catalog'), findsOneWidget);
    expect(find.text('Jacket'), findsOneWidget);
    expect(repository.catalogCalls, 1);
    expect(repository.opens, 0); // Listing did not create save events.
    expect(find.byKey(const Key('catalog-cached-dot-source-1')), findsNothing);

    await tester.tap(find.text('Jacket'));
    await tester.pumpAndSettle();
    expect(repository.opens, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('catalog-cached-dot-source-1')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();
    expect(
      find.text('Catalog loaded from cache · no catalog request'),
      findsOneWidget,
    );
    expect(repository.catalogCalls, 1);
    expect(
      find.byKey(const Key('catalog-cached-dot-source-1')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Refresh recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('Fetched fresh catalog'), findsOneWidget);
    expect(repository.catalogCalls, 2);

    await tester.tap(find.text('Jacket'));
    await tester.pumpAndSettle();
    expect(repository.opens, 1);
    expect(repository.compactOpens, 1);
    expect(find.text('Save this product'), findsOneWidget);
  });
}
