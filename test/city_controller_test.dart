import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/city.dart';
import 'package:whynot_mobile/models/repositories/city_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/profile_screen.dart';

import 'fakes/app_dependencies_fixture.dart';

class _CountingCityRepository implements CityRepository {
  int calls = 0;

  @override
  Future<List<City>> getCities() async {
    calls++;
    return const [City(id: 'bogota', name: 'Bogotá')];
  }
}

void main() {
  testWidgets('profile reuses its city request when the view rebuilds', (
    tester,
  ) async {
    final cities = _CountingCityRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      cityRepository: cities,
      profiles: const [
        UserProfile(
          id: 'test-user',
          name: 'Test User',
          email: 'user@example.com',
          gender: 'Female',
          age: 22,
          preferredCategoryId: 'fashion',
          cityId: 'bogota',
        ),
      ],
    );

    Widget app(String title) => DependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(title: title, home: const ProfileScreen()),
    );

    await tester.pumpWidget(app('first'));
    await tester.pumpAndSettle();
    expect(find.text('Bogotá'), findsOneWidget);
    expect(cities.calls, 1);

    await tester.pumpWidget(app('second'));
    await tester.pumpAndSettle();
    expect(find.text('Bogotá'), findsOneWidget);
    expect(cities.calls, 1);
  });

  testWidgets('profile does not request cities without a selected city', (
    tester,
  ) async {
    final cities = _CountingCityRepository();
    final dependencies = createTestDependencies(
      signedIn: true,
      cityRepository: cities,
      profiles: const [
        UserProfile(
          id: 'test-user',
          name: 'Test User',
          email: 'user@example.com',
          gender: 'Female',
          age: 22,
          preferredCategoryId: 'fashion',
        ),
      ],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not selected'), findsWidgets);
    expect(cities.calls, 0);
  });

  testWidgets('profile does not request cities while signed out', (
    tester,
  ) async {
    final cities = _CountingCityRepository();
    final dependencies = createTestDependencies(cityRepository: cities);

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No user logged in.'), findsOneWidget);
    expect(cities.calls, 0);
  });
}
