import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/controllers/recommendation_result_cache.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/recommendation_catalog_item.dart';
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

class CatalogRepository extends InMemoryRecommendationRepository {
  int catalogCalls = 0;
  int opens = 0;

  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    catalogCalls++;
    return const [catalogItem];
  }

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    opens++;
    expect(sourceProductId, catalogItem.sourceProductId);
    return const ProductRecommendation(
      recommendationEventId: 'event-1',
      name: 'Jacket',
      brand: 'Studio',
      price: 20000,
      imageUrl: '',
      productUrl: '',
      categoryId: 'fashion',
      reason: 'A similar user bought this.',
    );
  }
}

void main() {
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
        catalogCache:
            RecommendationResultCache<List<RecommendationCatalogItem>>(
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
    expect(find.text('Fetched fresh recommendations'), findsOneWidget);
    expect(find.text('Jacket'), findsOneWidget);
    expect(repository.catalogCalls, 1);
    expect(repository.opens, 0); // Listing did not create save events.

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();
    expect(
      find.text('Loaded from cache · no recommendation request'),
      findsOneWidget,
    );
    expect(repository.catalogCalls, 1);

    await tester.tap(find.byTooltip('Refresh recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('Fetched fresh recommendations'), findsOneWidget);
    expect(repository.catalogCalls, 2);

    await tester.tap(find.text('Jacket'));
    await tester.pumpAndSettle();
    expect(repository.opens, 1);
    expect(find.text('Save this product'), findsOneWidget);
  });
}
