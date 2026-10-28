import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/whynot_app.dart';
import 'package:whynot_mobile/controllers/auth_controller.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/home_controller.dart';
import 'package:whynot_mobile/controllers/profile_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/network_failure.dart';
import 'package:whynot_mobile/models/profile_photo.dart';
import 'package:whynot_mobile/models/repositories/auth_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/screens/edit_profile_screen.dart';
import 'package:whynot_mobile/views/screens/login_screen.dart';
import 'package:whynot_mobile/views/screens/profile_screen.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

class TestConnection extends ConnectivityStatus {
  TestConnection() : super(observe: false);
  @override
  Future<void> refresh() async {}
}

class CountingAuth extends InMemoryAuthRepository {
  int signIns = 0;
  int registrations = 0;
  int passwordChanges = 0;
  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    signIns++;
    return super.signIn(email: email, password: password);
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) {
    registrations++;
    return super.createUser(email: email, password: password);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges++;
  }
}

class ControlledUsers extends InMemoryUserRepository {
  int writes = 0;
  Completer<void>? confirmation;
  @override
  Future<void> update(String userId, UserProfileUpdate update) async {
    writes++;
    await confirmation?.future;
    await super.update(userId, update);
  }
}

class StreamingUsers extends InMemoryUserRepository {
  final records = StreamController<UserProfile?>();
  @override
  Stream<UserProfile?> watch(String userId) => records.stream;
}

const profile = UserProfile(
  id: 'test-user',
  name: 'Alice',
  email: 'alice@example.com',
  gender: 'Female',
  age: 22,
  preferredCategoryId: 'fashion',
  cityId: 'bogota',
  fromCache: true,
);
const update = UserProfileUpdate(
  name: 'Alicia',
  gender: 'Female',
  age: 22,
  preferredCategoryId: 'fashion',
  cityId: 'bogota',
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  test(
    'known offline auth is blocked, recovery never replays credentials',
    () async {
      final connection = TestConnection()..setStatus(NetworkStatus.offline);
      final repository = CountingAuth();
      final controller = AuthController(
        authRepository: repository,
        userRepository: InMemoryUserRepository(),
        connectivity: connection,
      );
      final offline = isA<AuthFailure>().having(
        (e) => e.code,
        'code',
        'network-request-failed',
      );
      await expectLater(
        controller.signIn(email: 'a@example.com', password: 'password'),
        throwsA(offline),
      );
      await expectLater(
        controller.createAccount(
          name: 'Alice',
          email: 'a@example.com',
          password: 'password',
          gender: 'Female',
          age: 22,
          preferredCategoryId: 'fashion',
          cityId: 'bogota',
        ),
        throwsA(offline),
      );
      await expectLater(
        controller.changePassword(
          currentPassword: 'password',
          newPassword: 'newpassword',
        ),
        throwsA(offline),
      );
      expect(repository.signIns, 0);
      expect(repository.registrations, 0);
      expect(repository.passwordChanges, 0);
      connection.setStatus(NetworkStatus.available);
      await flush();
      expect(repository.signIns, 0);
      await controller.signIn(email: 'a@example.com', password: 'password');
      expect(repository.signIns, 1);
      connection.dispose();
    },
  );

  test(
    'offline profile edits and uploads do not write; explicit retry works',
    () async {
      final connection = TestConnection()..setStatus(NetworkStatus.offline);
      final repository = ControlledUsers()..profiles[profile.id] = profile;
      final controller = ProfileController(
        authRepository: InMemoryAuthRepository(
          user: const AuthUser(id: 'test-user', email: 'alice@example.com'),
        ),
        userRepository: repository,
        photoRepository: InMemoryProfilePhotoRepository(),
        connectivity: connection,
      );
      await expectLater(
        controller.updateCurrentProfile(update),
        throwsA(isA<NetworkFailure>()),
      );
      // The connection guard runs before upload or photo-path writes.
      await expectLater(
        controller.savePhoto(
          ProfilePhoto(
            bytes: Uint8List(0),
            contentType: 'image/png',
            extension: 'png',
          ),
        ),
        throwsA(isA<NetworkFailure>()),
      );
      expect(repository.writes, 0);
      connection.setStatus(NetworkStatus.available);
      await flush();
      expect(repository.writes, 0);
      await controller.updateCurrentProfile(update);
      expect(repository.writes, 1);
      connection.dispose();
    },
  );

  test(
    'last data survives errors and reconnect retries only failed reads',
    () async {
      final connection = TestConnection();
      final profiles = StreamController<UserProfile?>.broadcast();
      final lists = StreamController<List<WishlistSummary>>.broadcast();
      var profileCalls = 0;
      var listCalls = 0;
      final controller = HomeController(
        connectivity: connection,
        watchProfile: () {
          profileCalls++;
          return profiles.stream;
        },
        watchWishlists: () {
          listCalls++;
          return lists.stream;
        },
      );
      await flush();
      profiles.add(profile);
      lists.add([]);
      await flush();
      connection.setStatus(NetworkStatus.offline);
      profiles.addError(StateError('network unavailable'));
      await flush();
      expect(controller.profile.snapshot.hasError, isTrue);
      expect(controller.profile.visibleSnapshot.data, profile);
      connection.setStatus(NetworkStatus.available);
      await flush();
      expect(profileCalls, 2);
      expect(listCalls, 1);
      expect(controller.profile.visibleSnapshot.data, profile);
      profiles.add(null);
      await flush();
      expect(controller.profile.visibleSnapshot.data, isNull);
      controller.dispose();
      connection.setStatus(NetworkStatus.offline);
      connection.setStatus(NetworkStatus.available);
      await flush();
      expect(profileCalls, 2);
      await profiles.close();
      await lists.close();
      connection.dispose();
    },
  );

  testWidgets(
    'login retains credentials offline and succeeds on explicit retry',
    (tester) async {
      mobile(tester);
      final connection = TestConnection()..setStatus(NetworkStatus.offline);
      final auth = CountingAuth();
      final dependencies = createTestDependencies(
        connectivity: connection,
        authRepositoryOverride: auth,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            home: const LoginScreen(),
            routes: {
              AppRoutes.home: (_) =>
                  const Scaffold(body: Text('Authenticated')),
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'alice@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      final login = find.text('Log in').last;
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      await tester.tap(login);
      await tester.runAsync(flush);
      await tester.pumpAndSettle();
      expect(auth.signIns, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'alice@example.com',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'password',
      );
      connection.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      expect(auth.signIns, 0);
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.text('Authenticated'), findsOneWidget);
      expect(auth.signIns, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    },
  );

  testWidgets(
    'offline Profile shows cached data and labels it as possibly outdated',
    (tester) async {
      mobile(tester);
      final connection = TestConnection()..setStatus(NetworkStatus.offline);
      final dependencies = createTestDependencies(
        signedIn: true,
        profiles: [profile],
        connectivity: connection,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Last available profile'), findsOneWidget);
      expect(
        find.text('Showing your saved profile while offline.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    },
  );

  testWidgets('pending and cached badges clear after fresh profile metadata', (
    tester,
  ) async {
    mobile(tester);
    final users = StreamingUsers();
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(
          signedIn: true,
          userRepositoryOverride: users,
        ),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    users.records.add(
      const UserProfile(
        id: 'test-user',
        name: 'Alice',
        email: 'alice@example.com',
        gender: 'Female',
        age: 22,
        preferredCategoryId: 'fashion',
        fromCache: true,
        hasPendingWrites: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile changes are pending'), findsOneWidget);
    users.records.add(profile);
    await tester.pumpAndSettle();
    expect(find.text('Profile changes are pending'), findsNothing);
    expect(find.text('Last available profile'), findsOneWidget);
    users.records.add(
      const UserProfile(
        id: 'test-user',
        name: 'Alice',
        email: 'alice@example.com',
        gender: 'Female',
        age: 22,
        preferredCategoryId: 'fashion',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last available profile'), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(users.records.hasListener, isFalse);
    unawaited(users.records.close());
    await tester.pump();
  });

  testWidgets('Profile explains when no local record is available offline', (
    tester,
  ) async {
    mobile(tester);
    final connection = TestConnection()..setStatus(NetworkStatus.offline);
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(
          signedIn: true,
          connectivity: connection,
        ),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No profile available offline on this device.'),
      findsOneWidget,
    );
    expect(find.text('Retry profile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });

  testWidgets('saved session reopens Home without reauthenticating offline', (
    tester,
  ) async {
    mobile(tester);
    final connection = TestConnection()..setStatus(NetworkStatus.offline);
    await tester.pumpWidget(
      WhyNotApp(
        dependencies: createTestDependencies(
          signedIn: true,
          profiles: [profile],
          connectivity: connection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Good Morning, Alice'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      find.text(
        'No wishlists available offline on this device. Connect to refresh.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });

  testWidgets(
    'profile form keeps offline edits and waits for server confirmation after retry',
    (tester) async {
      mobile(tester);
      final connection = TestConnection()..setStatus(NetworkStatus.offline);
      final users = ControlledUsers();
      final dependencies = createTestDependencies(
        signedIn: true,
        profiles: [profile],
        connectivity: connection,
        userRepositoryOverride: users,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                  child: const Text('Open edit profile'),
                ),
              ),
            ),
            routes: {AppRoutes.editProfile: (_) => const EditProfileScreen()},
          ),
        ),
      );
      await tester.tap(find.text('Open edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Alicia');
      final save = find.text('Save changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.runAsync(flush);
      await tester.pumpAndSettle();
      expect(users.writes, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'Alicia',
      );
      connection.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      expect(users.writes, 0);
      users.confirmation = Completer<void>();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(users.writes, 1);
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('Profile updated'), findsNothing);
      connection.setStatus(NetworkStatus.offline);
      await tester.pump();
      expect(
        find.textContaining('waiting for server confirmation'),
        findsOneWidget,
      );
      // Complete the supported pending write; do not issue a duplicate save.
      connection.setStatus(NetworkStatus.available);
      users.confirmation!.complete();
      await tester.pumpAndSettle();
      expect(users.writes, 1);
      expect(find.text('Profile updated'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    },
  );
}
