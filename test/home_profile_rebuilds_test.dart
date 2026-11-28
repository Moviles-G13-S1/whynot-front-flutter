import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/home_screen.dart';
import 'package:whynot_mobile/views/screens/profile_screen.dart';
import 'package:whynot_mobile/views/widgets/profile_controls.dart';
import 'package:whynot_mobile/views/widgets/selected_listenable_builder.dart';
import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

UserProfile _profile({
  String name = 'Alex Test',
  int age = 24,
  bool cached = false,
  bool pending = false,
  String? city = 'bogota',
}) => UserProfile(
  id: 'test-user',
  name: name,
  age: age,
  email: 'test@example.com',
  gender: 'Male',
  preferredCategoryId: 'technology',
  cityId: city,
  fromCache: cached,
  hasPendingWrites: pending,
);

class _Users extends InMemoryUserRepository {
  final events = StreamController<UserProfile?>.broadcast(sync: true);
  @override
  Stream<UserProfile?> watch(String userId) async* {
    yield _profile();
    yield* events.stream;
  }
}

void main() {
  testWidgets(
    'selector ignores equivalent records and detaches old and disposed sources',
    (tester) async {
      final first = ValueNotifier((name: 'Alex', age: 20));
      final second = ValueNotifier((name: 'Sam', age: 30));
      var builds = 0;
      Widget app(ValueNotifier<({String name, int age})> source) => MaterialApp(
        home: SelectedListenableBuilder<String>(
          listenable: source,
          select: () => source.value.name,
          builder: (_, name, _) {
            builds++;
            return Text(name);
          },
        ),
      );
      await tester.pumpWidget(app(first));
      expect(builds, 1);
      first.value = (name: 'Alex', age: 21);
      await tester.pump();
      expect(builds, 1);
      first.value = (name: 'Ana', age: 21);
      await tester.pump();
      expect(builds, 2);
      await tester.pumpWidget(app(second));
      expect(find.text('Sam'), findsOneWidget);
      final before = builds;
      first.value = (name: 'Old source', age: 22);
      await tester.pump();
      expect(builds, before);
      await tester.pumpWidget(const SizedBox.shrink());
      second.value = (name: 'Disposed', age: 31);
      await tester.pump();
      expect(tester.takeException(), isNull);
      first.dispose();
      second.dispose();
    },
  );

  testWidgets(
    'Home keeps the same greeting for age/metadata but updates the first name',
    (tester) async {
      final users = _Users();
      final network = ConnectivityStatus(observe: false);
      final deps = createTestDependencies(
        signedIn: true,
        userRepositoryOverride: users,
        connectivity: network,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final greeting = tester.widget(find.text('Good Morning, Alex'));
      users.events.add(_profile(age: 25, cached: true, pending: true));
      await tester.pumpAndSettle();
      expect(
        identical(greeting, tester.widget(find.text('Good Morning, Alex'))),
        isTrue,
      );
      users.events.add(_profile(name: 'Alex Different'));
      await tester.pumpAndSettle();
      expect(
        identical(greeting, tester.widget(find.text('Good Morning, Alex'))),
        isTrue,
      );
      users.events.add(_profile(name: 'Ana Test'));
      await tester.pumpAndSettle();
      expect(find.text('Good Morning, Ana'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await users.events.close();
      network.dispose();
    },
  );

  testWidgets(
    'Profile updates only changed fields while notices, errors and city keep working',
    (tester) async {
      final users = _Users();
      final network = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.available);
      final deps = createTestDependencies(
        signedIn: true,
        userRepositoryOverride: users,
        connectivity: network,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      ProfileValue field(String label) => tester
          .widgetList<ProfileValue>(find.byType(ProfileValue))
          .firstWhere((w) => w.label == label);
      final email = field('Email');
      final age = field('Age');
      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      users.events.add(_profile(age: 25));
      await tester.pumpAndSettle();
      expect(field('Age').value, '25');
      expect(identical(age, field('Age')), isFalse);
      expect(identical(email, field('Email')), isTrue);
      expect(
        identical(avatar, tester.widget(find.byType(ProfileAvatar))),
        isTrue,
      );
      final updatedAge = field('Age');
      users.events.add(_profile(age: 25, cached: true, pending: true));
      await tester.pumpAndSettle();
      expect(find.text('Profile changes are pending'), findsOneWidget);
      expect(identical(updatedAge, field('Age')), isTrue);
      network.setStatus(NetworkStatus.offline);
      users.events.add(_profile(age: 25));
      await tester.pumpAndSettle();
      expect(
        find.text('Showing your saved profile while offline.'),
        findsOneWidget,
      );
      expect(identical(email, field('Email')), isTrue);
      users.events.add(_profile(age: 25, city: 'medellin', name: 'Ana Test'));
      await tester.pumpAndSettle();
      expect(field('City').value, 'Medellín');
      expect(find.text('Ana Test'), findsOneWidget);
      users.events.addError(StateError('connection lost'));
      await tester.pumpAndSettle();
      expect(find.text('Retry profile'), findsOneWidget);
      expect(identical(email, field('Email')), isTrue);
      expect(find.text('Ana Test'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await users.events.close();
      network.dispose();
    },
  );
}
