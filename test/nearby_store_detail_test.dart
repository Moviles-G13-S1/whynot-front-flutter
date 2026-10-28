import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/whynot_theme.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/nearby_store_controller.dart';
import 'package:whynot_mobile/models/nearby_store.dart';
import 'package:whynot_mobile/views/screens/nearby_store_detail_screen.dart';
import 'package:whynot_mobile/views/widgets/nearby_store_section.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_location_repository.dart';
import 'fakes/in_memory_nearby_store_repository.dart';

const store = NearbyStore(
  id: 'local-store',
  name: 'WhyNot Studio',
  address: 'Carrera 7 # 20-10, Bogotá',
  latitude: 4.66,
  longitude: -74.05,
  categoryIds: ['fashion', 'beauty', 'travel'],
  websiteUrl: 'https://example.com/store',
  imageUrl: '',
  distanceKm: 0.5,
);

class CountingNearbyRepository extends InMemoryNearbyStoreRepository {
  CountingNearbyRepository() : super(store: store);
  int calls = 0;

  @override
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  }) {
    calls++;
    return super.getNearestStore(latitude: latitude, longitude: longitude);
  }
}

void main() {
  testWidgets('Home opens the selected store without another backend call', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CountingNearbyRepository();
    final controller = NearbyStoreController(
      locationRepository: InMemoryLocationRepository(),
      nearbyStoreRepository: repository,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(nearbyStoreController: controller),
        child: MaterialApp(
          theme: WhyNotTheme.data,
          home: const Scaffold(body: NearbyStoreSection()),
          routes: {
            AppRoutes.nearbyStoreDetail: (_) => const NearbyStoreDetailScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(find.text('View store'), findsNothing);
    await tester.tap(find.text(store.name));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyStoreDetailScreen), findsOneWidget);
    expect(find.text(store.name), findsOneWidget);
    expect(find.text(store.address), findsOneWidget);
    expect(find.text('500 m away'), findsOneWidget);
    expect(find.text('Image unavailable'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Store website'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(store.websiteUrl), findsOneWidget);
    expect(find.text('Fashion'), findsOneWidget);
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Travel'), findsNothing);
    expect(repository.calls, 1);
    await tester.scrollUntilVisible(
      find.byTooltip('Back'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyStoreDetailScreen), findsNothing);
    expect(find.text(store.name), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale detail keeps content and observes offline changes', (
    tester,
  ) async {
    final dependencies = createTestDependencies();
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          theme: WhyNotTheme.data,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: NearbyStoreResult(store, stale: true),
            ),
            builder: (_) => const NearbyStoreDetailScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last checked · 500 m away'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Last nearby match'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MAY BE OUTDATED'), findsOneWidget);
    dependencies.nearbyStoreController.connectivity.setStatus(
      NetworkStatus.offline,
    );
    await tester.pump();
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text(store.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing route data offers a safe return to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(),
        child: MaterialApp(
          theme: WhyNotTheme.data,
          home: const NearbyStoreDetailScreen(),
          routes: {AppRoutes.home: (_) => const Scaffold(body: Text('Home'))},
        ),
      ),
    );
    expect(find.text('No store selected'), findsOneWidget);
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();
    expect(find.text('No store selected'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
