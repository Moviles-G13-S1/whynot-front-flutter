import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/city.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/home_screen.dart';
import 'package:whynot_mobile/views/screens/profile_screen.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

class _DelayedCities extends InMemoryCityRepository {
  final pending = Completer<List<City>>();
  int calls = 0;
  @override
  Future<List<City>> getCities() {
    calls++;
    return calls == 1 ? pending.future : Future.value(cities);
  }
}

class _DelayedWishlists extends InMemoryWishlistRepository {
  final pending = Completer<List<Category>>();
  int calls = 0;
  @override
  Future<List<Category>> getCategories() {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'Profile remains usable with delayed cities; rebuild does not reload; retry is local',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cities = _DelayedCities();
      final dependencies = createTestDependencies(
        signedIn: true,
        profiles: const [
          UserProfile(
            id: 'test-user',
            name: 'Alice',
            email: 'alice@example.com',
            gender: 'Female',
            age: 22,
            preferredCategoryId: 'fashion',
            cityId: 'bogota',
          ),
        ],
        cityRepository: cities,
      );
      Widget app() => DependenciesScope(
        dependencies: dependencies,
        // Create a new widget instance to actually exercise rebuilding.
        // ignore: prefer_const_constructors
        child: MaterialApp(home: ProfileScreen(key: const ValueKey('profile'))),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      expect(cities.calls, 1);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Loading city...'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(cities.calls, 1);
      cities.pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('City unavailable'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry city'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry city'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(cities.calls, 2);
      expect(find.text('Bogotá'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home shows greeting while wishlists load and rebuild does not restart them',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final wishlists = _DelayedWishlists();
      final dependencies = createTestDependencies(
        signedIn: true,
        wishlistRepositoryOverride: wishlists,
        profiles: const [
          UserProfile(
            id: 'test-user',
            name: 'Alice',
            email: 'alice@example.com',
            gender: 'Female',
            age: 22,
            preferredCategoryId: 'fashion',
          ),
        ],
      );
      Widget app() => DependenciesScope(
        dependencies: dependencies,
        // Create a new widget instance to actually exercise rebuilding.
        // ignore: prefer_const_constructors
        child: MaterialApp(home: HomeScreen(key: const ValueKey('home'))),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Good Morning, Alice'), findsOneWidget);
      expect(wishlists.calls, 1);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(wishlists.calls, 1);
      wishlists.pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Create your first wishlist.'), findsOneWidget);
      expect(find.text('Good Morning, Alice'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
