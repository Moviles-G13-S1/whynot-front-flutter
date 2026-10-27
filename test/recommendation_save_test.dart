import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/widgets/smart_recommendation_section.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';

const recommendation = ProductRecommendation(
  recommendationEventId: 'event-123',
  name: 'Jacket',
  brand: 'Brand',
  price: 100,
  imageUrl: '',
  productUrl: '',
  categoryId: 'fashion',
  reason: 'Users like you saved this.',
);

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  testWidgets('saves a recommendation into a matching wishlist once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryRecommendationRepository(
      recommendation: recommendation,
    );
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
      categories: const [Category(id: 'fashion', name: 'Fashion')],
      wishlists: const [
        Wishlist(
          id: 'fashion-list',
          ownerId: 'test-user',
          categoryId: 'fashion',
          imageUrl: '',
        ),
        Wishlist(
          id: 'other-list',
          ownerId: 'test-user',
          categoryId: 'other',
          imageUrl: '',
        ),
      ],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(
          home: Scaffold(body: SmartRecommendationSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this product'));
    await tester.pumpAndSettle();
    expect(find.text('Fashion'), findsOneWidget);
    expect(find.text('Create wishlist and save'), findsNothing);
    await tester.tap(find.text('Fashion'));
    await tester.pumpAndSettle();

    expect(repository.saves, [
      (recommendationEventId: 'event-123', wishlistId: 'fashion-list'),
    ]);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('creates a category wishlist when none matches before saving', (
    tester,
  ) async {
    final repository = InMemoryRecommendationRepository(
      recommendation: recommendation,
    );
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
      categories: const [Category(id: 'fashion', name: 'Fashion')],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(
          home: Scaffold(body: SmartRecommendationSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this product'));
    await tester.pumpAndSettle();
    expect(
      find.text('You need a wishlist in this category first.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Create wishlist and save'));
    await tester.pumpAndSettle();

    expect(repository.saves, [
      (recommendationEventId: 'event-123', wishlistId: 'wishlist-1'),
    ]);
    expect(find.text('Saved'), findsOneWidget);
  });
}
