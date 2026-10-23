import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/repositories/recommendation_repository.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/screens/recommendation_detail_screen.dart';
import 'package:whynot_mobile/views/widgets/smart_recommendation_section.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';

const detailRecommendation = ProductRecommendation(
  recommendationEventId: 'detail-event',
  name: 'Leather Jacket',
  brand: 'WhyNot Studio',
  price: 250000,
  imageUrl: '',
  productUrl: 'https://example.com/jacket',
  categoryId: 'fashion-accessories',
  reason: 'People with similar wishlists saved this product.',
);

class _ScriptedRecommendationRepository implements RecommendationRepository {
  _ScriptedRecommendationRepository(this.responses, {this.saveCompleter});

  final List<Future<ProductRecommendation?> Function()> responses;
  final Completer<void>? saveCompleter;
  final saves = <({String recommendationEventId, String wishlistId})>[];
  var calls = 0;

  @override
  Future<ProductRecommendation?> getRecommendation() {
    final response = responses[calls.clamp(0, responses.length - 1)];
    calls += 1;
    return response();
  }

  @override
  Future<void> saveRecommendation({
    required String recommendationEventId,
    required String wishlistId,
  }) async {
    saves.add((
      recommendationEventId: recommendationEventId,
      wishlistId: wishlistId,
    ));
    await saveCompleter?.future;
  }
}

Widget _detailApp(RecommendationRepository repository) {
  return DependenciesScope(
    dependencies: createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    ),
    child: const MaterialApp(home: RecommendationDetailScreen()),
  );
}

void main() {
  testWidgets('detail shows the recommendation content', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _detailApp(
        InMemoryRecommendationRepository(recommendation: detailRecommendation),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leather Jacket'), findsOneWidget);
    expect(find.text('WhyNot Studio'), findsOneWidget);
    expect(find.text(r'$250.000'), findsOneWidget);
    expect(find.text('Fashion Accessories'), findsOneWidget);
    expect(
      find.text('People with similar wishlists saved this product.'),
      findsOneWidget,
    );
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.text('Save this product'), findsOneWidget);
  });

  testWidgets('detail exposes loading and empty states', (tester) async {
    final pending = Completer<ProductRecommendation?>();
    await tester.pumpWidget(
      _detailApp(_ScriptedRecommendationRepository([() => pending.future])),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Loading recommendation'), findsOneWidget);

    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('No recommendation yet'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });

  testWidgets('detail retries after an error', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScriptedRecommendationRepository([
      () => Future<ProductRecommendation?>.error(StateError('offline')),
      () => Future<ProductRecommendation?>.value(detailRecommendation),
    ]);
    await tester.pumpWidget(_detailApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your recommendation'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Leather Jacket'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('tapping the card opens detail without requesting again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScriptedRecommendationRepository([
      () => Future<ProductRecommendation?>.value(detailRecommendation),
      () => Future<ProductRecommendation?>.error(
        StateError('unexpected second request'),
      ),
    ]);
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          home: const Scaffold(body: SmartRecommendationSection()),
          routes: {
            AppRoutes.recommendationDetail: (_) =>
                const RecommendationDetailScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View details'), findsNothing);
    await tester.tap(find.text('Leather Jacket'));
    await tester.pumpAndSettle();

    expect(find.text('Recommendation'), findsOneWidget);
    expect(find.text('Leather Jacket'), findsOneWidget);
    expect(repository.calls, 1);
  });

  testWidgets('detail moves from saving to saved state', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saveCompleter = Completer<void>();
    final repository = _ScriptedRecommendationRepository([
      () => Future<ProductRecommendation?>.value(detailRecommendation),
    ], saveCompleter: saveCompleter);
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
      categories: const [Category(id: 'fashion-accessories', name: 'Fashion')],
      wishlists: const [
        Wishlist(
          id: 'fashion-list',
          ownerId: 'test-user',
          categoryId: 'fashion-accessories',
          imageUrl: '',
        ),
      ],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(home: RecommendationDetailScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fashion'));
    await tester.pump();

    expect(find.text('Saving...'), findsOneWidget);
    saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Saved to wishlist'), findsOneWidget);
    expect(
      find.text('This recommendation is in your wishlist.'),
      findsOneWidget,
    );
    expect(repository.saves, [
      (recommendationEventId: 'detail-event', wishlistId: 'fashion-list'),
    ]);
  });
}
