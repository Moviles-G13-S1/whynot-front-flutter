import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/controllers/nearby_store_controller.dart';
import 'package:whynot_mobile/models/device_location.dart';
import 'package:whynot_mobile/models/nearby_failure.dart';
import 'package:whynot_mobile/models/nearby_store.dart';
import 'package:whynot_mobile/models/repositories/location_repository.dart';
import 'package:whynot_mobile/models/repositories/nearby_store_repository.dart';
import 'package:whynot_mobile/views/widgets/nearby_store_section.dart';

import 'fakes/app_dependencies_fixture.dart';

class FakeLocation implements LocationRepository {
  NearbyFailureKind? failure;
  int calls = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;
  final permissionRequests = <bool>[];

  @override
  Future<DeviceLocation> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    calls++;
    permissionRequests.add(requestPermission);
    if (failure != null) throw NearbyFailure(failure!);
    return const DeviceLocation(latitude: 4.66, longitude: -74.05);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return true;
  }
}

class FakeNearby implements NearbyStoreRepository {
  int calls = 0;
  bool fails = false;
  NearbyStore? store;

  @override
  Future<NearbyStore?> getNearestStore({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    assert(latitude == 4.66 && longitude == -74.05);
    if (fails) throw Exception('network location error');
    return store;
  }
}

const exampleStore = NearbyStore(
  id: 'store',
  name: 'Local Store',
  address: 'Main Street',
  latitude: 4.67,
  longitude: -74.04,
  categoryIds: [],
  websiteUrl: '',
  imageUrl: '',
  distanceKm: 0.5,
);

void main() {
  late FakeLocation location;
  late FakeNearby nearby;
  late NearbyStoreController controller;

  setUp(() {
    location = FakeLocation();
    nearby = FakeNearby();
    controller = NearbyStoreController(
      locationRepository: location,
      nearbyStoreRepository: nearby,
    );
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DependenciesScope(
          dependencies: createTestDependencies(
            nearbyStoreController: controller,
          ),
          child: const Scaffold(body: NearbyStoreSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final failure in [
    NearbyFailureKind.permissionDenied,
    NearbyFailureKind.permissionPermanentlyDenied,
    NearbyFailureKind.servicesDisabled,
    NearbyFailureKind.locationUnavailable,
  ]) {
    test('controller stops before backend on $failure', () async {
      location.failure = failure;
      await expectLater(
        controller.getNearestStore(),
        throwsA(
          isA<NearbyFailure>().having((error) => error.kind, 'kind', failure),
        ),
      );
      expect(nearby.calls, 0);
    });
  }

  test('backend failure is distinct from location permission', () async {
    nearby.fails = true;
    await expectLater(
      controller.getNearestStore(),
      throwsA(
        isA<NearbyFailure>().having(
          (error) => error.kind,
          'kind',
          NearbyFailureKind.nearbyServiceUnavailable,
        ),
      ),
    );
    expect(location.calls, 1);
    expect(nearby.calls, 1);
  });

  test('success and no-store responses are preserved', () async {
    expect(await controller.getNearestStore(), isNull);
    nearby.store = exampleStore;
    expect(await controller.getNearestStore(), same(exampleStore));
  });

  testWidgets('denied permission has a single prompt attempt and retry', (
    tester,
  ) async {
    location.failure = NearbyFailureKind.permissionDenied;
    await pumpSection(tester);
    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Try permission again'), findsOneWidget);
    expect(find.text('Local Store'), findsNothing);
    expect(nearby.calls, 0);
    expect(location.calls, 1);

    await tester.pump(); // A rebuild must not request permission again.
    expect(location.calls, 1);
    location.failure = null;
    nearby.store = exampleStore;
    await tester.tap(find.text('Try permission again'));
    await tester.pumpAndSettle();
    expect(find.text('Local Store'), findsOneWidget);
    expect(location.calls, 2);
    expect(nearby.calls, 1);
  });

  testWidgets(
    'permanent denial opens app settings and refreshes once on resume',
    (tester) async {
      location.failure = NearbyFailureKind.permissionPermanentlyDenied;
      await pumpSection(tester);
      await tester.tap(find.text('Open app settings'));
      await tester.pump();
      expect(location.appSettingsCalls, 1);
      location.failure = null;
      nearby.store = exampleStore;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(location.calls, 2);
      expect(nearby.calls, 1);
      expect(find.text('Local Store'), findsOneWidget);
      expect(location.permissionRequests, [true, false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(location.calls, 2);
      expect(nearby.calls, 1);
    },
  );

  testWidgets('disabled services opens location settings', (tester) async {
    location.failure = NearbyFailureKind.servicesDisabled;
    await pumpSection(tester);
    expect(find.text('Location services are off'), findsOneWidget);
    await tester.tap(find.text('Open location settings'));
    await tester.pump();
    expect(location.locationSettingsCalls, 1);
    expect(nearby.calls, 0);
    location.failure = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.permissionRequests, [true, false]);
    expect(nearby.calls, 1);
  });

  testWidgets('no fix and backend failure show distinct guidance', (
    tester,
  ) async {
    location.failure = NearbyFailureKind.locationUnavailable;
    await pumpSection(tester);
    expect(find.text('Could not get your location'), findsOneWidget);
    expect(find.textContaining('signal is unavailable'), findsOneWidget);
    location.failure = null;
    nearby.fails = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('We could not load nearby stores'), findsOneWidget);
    expect(find.textContaining('nearby service or network'), findsOneWidget);
    expect(find.text('Location permission denied'), findsNothing);
    nearby.fails = false;
    nearby.store = exampleStore;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Local Store'), findsOneWidget);
  });

  testWidgets('null backend result keeps empty state', (tester) async {
    await pumpSection(tester);
    expect(find.text('Nothing nearby just yet.'), findsOneWidget);
  });
}
