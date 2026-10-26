import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/views/screens/recommendation_detail_screen.dart';
import 'package:whynot_mobile/views/widgets/smart_recommendation_section.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';

const card = ProductRecommendation(
  recommendationEventId: 'cached-or-fresh',
  name: 'Jacket',
  brand: 'Brand',
  price: 100,
  imageUrl: '',
  productUrl: '',
  categoryId: 'fashion',
  reason: 'For you',
);

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets(
    'offscreen card is not displayed; visible cached result records once through rebuilds',
    (tester) async {
      final repository = InMemoryRecommendationRepository(recommendation: card);
      final dependencies = createTestDependencies(
        signedIn: true,
        recommendationRepository: repository,
      );
      Widget app() => DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 1000),
                  SmartRecommendationSection(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(repository.homeEvents, isEmpty);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -850),
      );
      await tester.pumpAndSettle();
      expect(repository.homeEvents.length, 1);
      expect(repository.homeEvents.single.eventType, 'card_displayed');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(repository.homeEvents.length, 1);
    },
  );

  testWidgets(
    'one visible Home tap pairs with its display; direct detail route emits nothing',
    (tester) async {
      final repository = InMemoryRecommendationRepository(recommendation: card);
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
                  const Scaffold(body: Text('Detail page')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        repository.homeEvents
            .where((e) => e.eventType == 'card_displayed')
            .length,
        1,
      );
      final cardTap = tester
          .widget<InkWell>(
            find
                .ancestor(
                  of: find.text('Jacket'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .onTap!;
      cardTap();
      cardTap();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
      expect(repository.homeEvents.length, 2);
      expect(
        repository.homeEvents[0].impressionId,
        repository.homeEvents[1].impressionId,
      );
      expect(repository.homeEvents[1].eventType, 'detail_opened');
      Navigator.pop(tester.element(find.text('Detail page')));
      await tester.pumpAndSettle();
      expect(
        repository.homeEvents
            .where((e) => e.eventType == 'card_displayed')
            .length,
        2,
      );
      expect(
        repository.homeEvents.last.impressionId,
        isNot(repository.homeEvents.first.impressionId),
      );
    },
  );

  testWidgets('direct detail route without a Home card records no events', (
    tester,
  ) async {
    final repository = InMemoryRecommendationRepository(recommendation: card);
    final dependencies = createTestDependencies(
      signedIn: true,
      recommendationRepository: repository,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(home: RecommendationDetailScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.homeEvents, isEmpty);
  });
}
