import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/nearby_store_controller.dart';
import 'package:whynot_mobile/controllers/recommendation_catalog_snapshot_cache.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/controllers/recommendation_result_cache.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/device_location.dart';
import 'package:whynot_mobile/models/nearby_failure.dart';
import 'package:whynot_mobile/models/nearby_store.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/recommendation_catalog_item.dart';
import 'package:whynot_mobile/models/repositories/location_repository.dart';
import 'package:whynot_mobile/models/repositories/nearby_store_repository.dart';
import 'package:whynot_mobile/views/screens/recommendation_catalog_screen.dart';
import 'package:whynot_mobile/views/screens/recommendation_detail_screen.dart';
import 'package:whynot_mobile/views/widgets/nearby_store_section.dart';
import 'package:whynot_mobile/views/widgets/smart_recommendation_section.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';
import 'fakes/in_memory_repositories.dart';

const item = RecommendationCatalogItem(
  sourceProductId: 'p1',
  name: 'Coat',
  brand: '',
  price: 10,
  imageUrl: '',
  categoryId: 'fashion',
  reason: 'Matched',
);
const pick = ProductRecommendation(
  recommendationEventId: 'event',
  name: 'Coat',
  brand: '',
  price: 10,
  imageUrl: '',
  productUrl: '',
  categoryId: 'fashion',
  reason: 'Matched',
);

class VariableRecommendations extends InMemoryRecommendationRepository {
  VariableRecommendations() : super(recommendation: pick);
  int calls = 0;
  bool fail = false;
  bool failOpen = false;
  bool failPick = false;
  int pickCalls = 0;
  List<RecommendationCatalogItem> items = [item];
  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    calls++;
    if (fail) throw StateError('backend');
    return items;
  }

  @override
  Future<ProductRecommendation?> getRecommendation() async {
    pickCalls++;
    if (failPick) throw StateError('backend');
    return pick;
  }

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    if (failOpen) throw StateError('backend');
    return pick;
  }
}

class MovingLocation implements LocationRepository {
  DeviceLocation current = const DeviceLocation(
    latitude: 4.66,
    longitude: -74.05,
  );
  NearbyFailureKind? failure;
  @override
  Future<DeviceLocation> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    if (failure != null) throw NearbyFailure(failure!);
    return current;
  }

  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

const store = NearbyStore(
  id: 's',
  name: 'Shop',
  address: 'Here',
  latitude: 4.66,
  longitude: -74.05,
  categoryIds: [],
  websiteUrl: '',
  imageUrl: '',
  distanceKm: 0.3,
);

class VariableNearby implements NearbyStoreRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    if (fail) throw StateError('backend');
    return store;
  }
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  test(
    'expired recommendation and catalog stay available only as stale fallback',
    () async {
      var now = DateTime(2026);
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@test.com'),
      );
      final net = ConnectivityStatus(observe: false);
      final repo = VariableRecommendations();
      final controller = RecommendationController(
        recommendationRepository: repo,
        authRepository: auth,
        connectivity: net,
        cache: RecommendationResultCache(clock: () => now),
        catalogSnapshotCache: RecommendationCatalogSnapshotCache(
          clock: () => now,
        ),
      );
      expect(await controller.getRecommendation(), pick);
      expect((await controller.getCatalog()).items, [item]);
      now = now.add(const Duration(minutes: 6));
      net.setStatus(NetworkStatus.offline);
      await expectLater(controller.getRecommendation(), throwsStateError);
      await expectLater(controller.getCatalog(), throwsStateError);
      expect(controller.staleRecommendation, pick);
      expect(controller.staleCatalog, [item]);
      expect(repo.calls, 1);
      net.setStatus(NetworkStatus.available);
      repo.fail = true;
      await expectLater(
        controller.getCatalog(forceRefresh: true),
        throwsStateError,
      );
      expect(controller.staleCatalog, [item]);
      repo.fail = false;
      repo.items = [];
      expect((await controller.getCatalog(forceRefresh: true)).items, isEmpty);
      expect(controller.staleCatalog, isNull);
      controller.invalidateForUser('a');
      expect(controller.staleRecommendation, isNull);
    },
  );

  test(
    'offline has no result, cannot save, and user switch clears fallback',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@test.com'),
      );
      final net = ConnectivityStatus(observe: false);
      final repo = VariableRecommendations();
      final controller = RecommendationController(
        recommendationRepository: repo,
        authRepository: auth,
        connectivity: net,
      );
      net.setStatus(NetworkStatus.offline);
      await expectLater(controller.getRecommendation(), throwsStateError);
      await expectLater(controller.getCatalog(), throwsStateError);
      await expectLater(
        controller.saveRecommendation(recommendation: pick, wishlistId: 'w'),
        throwsStateError,
      );
      expect(repo.saves, isEmpty);
      net.setStatus(NetworkStatus.available);
      await controller.getCatalog();
      auth.user = const AuthUser(id: 'b', email: 'b@test.com');
      expect(controller.staleCatalog, isNull);
      await controller.getCatalog();
      expect(repo.calls, 2);
    },
  );

  testWidgets(
    'catalog marks stale, disables refresh, and auto refreshes on reconnection',
    (tester) async {
      final repo = VariableRecommendations();
      final dependencies = createTestDependencies(
        signedIn: true,
        recommendationRepository: repo,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DependenciesScope(
            dependencies: dependencies,
            child: const RecommendationCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      final net = dependencies.recommendationController.connectivity;
      net.setStatus(NetworkStatus.offline);
      await tester.pumpAndSettle();
      expect(find.textContaining('Outdated catalog'), findsOneWidget);
      final refresh = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(refresh.onPressed, isNull);
      expect(repo.calls, 1);
      repo.items = [];
      net.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsNothing);
      expect(
        find.text('No new recommendations yet. Try again later.'),
        findsOneWidget,
      );
      expect(repo.calls, 2);
    },
  );

  testWidgets(
    'Home and catalog explain confirmed offline with no previous data',
    (tester) async {
      final repo = VariableRecommendations();
      final deps = createTestDependencies(
        signedIn: true,
        recommendationRepository: repo,
      );
      deps.recommendationController.connectivity.setStatus(
        NetworkStatus.offline,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(
            home: Scaffold(body: SmartRecommendationSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('New recommendations cannot be fetched'),
        findsOneWidget,
      );
      expect(repo.pickCalls, 0);
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(home: RecommendationCatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No previous recommendations are available'),
        findsOneWidget,
      );
      expect(repo.calls, 0);
    },
  );

  testWidgets(
    'Home keeps a marked pick offline and recovers after a failed reconnection',
    (tester) async {
      final repo = VariableRecommendations();
      final deps = createTestDependencies(
        signedIn: true,
        recommendationRepository: repo,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(
            home: Scaffold(body: SmartRecommendationSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      expect(
        repo.homeEvents.where((e) => e.eventType == 'card_displayed').length,
        1,
      );
      final net = deps.recommendationController.connectivity;
      net.setStatus(NetworkStatus.offline);
      await tester.pumpAndSettle();
      expect(find.textContaining('Outdated recommendation'), findsOneWidget);
      expect(find.text('Saving is unavailable offline.'), findsOneWidget);
      expect(
        repo.homeEvents.where((e) => e.eventType == 'card_displayed').length,
        1,
      );
      repo.failPick = true;
      net.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      expect(find.textContaining('Could not refresh'), findsOneWidget);
      repo.failPick = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not refresh'), findsNothing);
      expect(repo.pickCalls, 3);
    },
  );

  test(
    'nearby fallback requires same user and location within 100 meters',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@test.com'),
      );
      final net = ConnectivityStatus(observe: false);
      final location = MovingLocation();
      final repo = VariableNearby();
      final controller = NearbyStoreController(
        locationRepository: location,
        nearbyStoreRepository: repo,
        authRepository: auth,
        connectivity: net,
      );
      expect((await controller.getNearestStoreResult()).stale, false);
      net.setStatus(NetworkStatus.offline);
      expect((await controller.getNearestStoreResult()).stale, true);
      expect(repo.calls, 1);
      location.current = const DeviceLocation(
        latitude: 4.67,
        longitude: -74.05,
      );
      await expectLater(
        controller.getNearestStoreResult(),
        throwsA(isA<NearbyFailure>()),
      );
      location.current = const DeviceLocation(
        latitude: 4.66,
        longitude: -74.05,
      );
      auth.user = const AuthUser(id: 'b', email: 'b@test.com');
      await expectLater(
        controller.getNearestStoreResult(),
        throwsA(isA<NearbyFailure>()),
      );
    },
  );

  testWidgets(
    'backend-only catalog failure keeps previous list and retry works',
    (tester) async {
      final repo = VariableRecommendations();
      final deps = createTestDependencies(
        signedIn: true,
        recommendationRepository: repo,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DependenciesScope(
            dependencies: deps,
            child: const RecommendationCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.fail = true;
      await tester.tap(find.byTooltip('Refresh recommendations'));
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      expect(find.textContaining('Refresh failed'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      expect(find.textContaining('Refresh failed'), findsNothing);
    },
  );

  testWidgets(
    'offline catalog detail shows preview but cannot save until rechecked',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = VariableRecommendations();
      final deps = createTestDependencies(
        signedIn: true,
        recommendationRepository: repo,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: MaterialApp(
            home: const RecommendationCatalogScreen(),
            routes: {
              AppRoutes.recommendationDetail: (_) =>
                  const RecommendationDetailScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      deps.recommendationController.connectivity.setStatus(
        NetworkStatus.offline,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coat'));
      await tester.pumpAndSettle();
      expect(find.text('Coat'), findsOneWidget);
      expect(find.text('Saving is unavailable offline'), findsOneWidget);
      expect(repo.saves, isEmpty);
      deps.recommendationController.connectivity.setStatus(
        NetworkStatus.available,
      );
      await tester.pumpAndSettle();
      expect(find.text('Save this product'), findsOneWidget);
    },
  );

  testWidgets('already open Home detail rechecks after offline before save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = VariableRecommendations();
    final deps = createTestDependencies(
      signedIn: true,
      recommendationRepository: repo,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: deps,
        child: const MaterialApp(home: RecommendationDetailScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.pickCalls, 1);
    final net = deps.recommendationController.connectivity;
    net.setStatus(NetworkStatus.offline);
    await tester.pumpAndSettle();
    expect(find.text('Saving is unavailable offline'), findsOneWidget);
    net.setStatus(NetworkStatus.available);
    await tester.pumpAndSettle();
    expect(repo.pickCalls, 2);
    expect(find.text('Save this product'), findsOneWidget);
  });

  testWidgets(
    'nearby backend failure keeps safe store and retry gets fresh result',
    (tester) async {
      final location = MovingLocation();
      final repo = VariableNearby();
      final net = ConnectivityStatus(observe: false);
      final controller = NearbyStoreController(
        locationRepository: location,
        nearbyStoreRepository: repo,
        connectivity: net,
      );
      final deps = createTestDependencies(nearbyStoreController: controller);
      await tester.pumpWidget(
        MaterialApp(
          home: DependenciesScope(
            dependencies: deps,
            child: const Scaffold(body: NearbyStoreSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.fail = true;
      net.setStatus(NetworkStatus.offline);
      await tester.pumpAndSettle();
      net.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      expect(find.textContaining('Outdated nearby result'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Outdated nearby result'), findsNothing);
      expect(find.text('Shop'), findsOneWidget);
    },
  );

  testWidgets(
    'nearby offline without safe previous result shows specific error',
    (tester) async {
      final net = ConnectivityStatus(observe: false);
      net.setStatus(NetworkStatus.offline);
      final repo = VariableNearby();
      final controller = NearbyStoreController(
        locationRepository: MovingLocation(),
        nearbyStoreRepository: repo,
        connectivity: net,
      );
      final deps = createTestDependencies(nearbyStoreController: controller);
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(home: Scaffold(body: NearbyStoreSection())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No previous store is safe'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(repo.calls, 0);
    },
  );
}
