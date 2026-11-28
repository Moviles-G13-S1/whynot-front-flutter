import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/models/profile_draft.dart';
import 'package:whynot_mobile/models/repositories/profile_draft_store.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/edit_profile_screen.dart';
import 'package:whynot_mobile/views/widgets/form_controls.dart';
import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

const profile = UserProfile(
  id: 'test-user',
  name: 'Alice',
  email: 'a@example.com',
  gender: 'Female',
  age: 24,
  preferredCategoryId: 'fashion',
  cityId: 'bogota',
);

class MemoryDrafts extends SerializedProfileDraftStore {
  final data = <String, ProfileDraft>{};
  @override
  Future<ProfileDraft?> load(String id) => serial(id, () async => data[id]);
  @override
  Future<void> save(String id, ProfileDraft draft) => serial(id, () async {
    data[id] = draft;
  });
  @override
  Future<void> clear(String id) => serial(id, () async {
    data.remove(id);
  });
}

class Connection extends ConnectivityStatus {
  Connection() : super(observe: false);
  @override
  Future<void> refresh() async {}
}

class FailingClearDrafts extends MemoryDrafts {
  @override
  Future<void> clear(String id) async =>
      throw StateError('Device storage unavailable');
}

class Users extends InMemoryUserRepository {
  Completer<void>? ack;
  int writes = 0;
  @override
  Future<void> update(String id, UserProfileUpdate update) async {
    writes++;
    await ack?.future;
    await super.update(id, update);
  }
}

void main() {
  testWidgets('local cleanup failure does not report a remote save failure', (
    tester,
  ) async {
    final store = FailingClearDrafts();
    final deps = createTestDependencies(
      signedIn: true,
      profiles: [profile],
      profileDraftStore: store,
    );
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: deps,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pumpAndSettle();
    final save = find.widgetWithText(PillButton, 'Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Profile updated, but the local draft could not be removed.',
      ),
      findsOneWidget,
    );
    expect(store.data['test-user']!.name, 'Ana');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'unsaved edits survive reopening and discard restores profile values',
    (tester) async {
      final store = MemoryDrafts();
      final deps = createTestDependencies(
        signedIn: true,
        profiles: [profile],
        profileDraftStore: store,
      );
      Widget form() => DependenciesScope(
        dependencies: deps,
        child: const MaterialApp(home: EditProfileScreen()),
      );
      await tester.pumpWidget(form());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.pumpAndSettle();
      expect(store.data['test-user']!.name, 'Ana');
      expect(find.textContaining('Draft saved on this device'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(form());
      await tester.pumpAndSettle();
      expect(find.text('Unsaved draft restored'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Ana',
      );
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(store.data, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Alice',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'offline and unconfirmed remote saves retain draft; acknowledgement clears it',
    (tester) async {
      final store = MemoryDrafts();
      final network = Connection()..setStatus(NetworkStatus.offline);
      final users = Users();
      final deps = createTestDependencies(
        signedIn: true,
        profiles: [profile],
        profileDraftStore: store,
        connectivity: network,
        userRepositoryOverride: users,
      );
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(PillButton, 'Save changes');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(users.writes, 0);
      expect(store.data['test-user']!.name, 'Ana');
      network.setStatus(NetworkStatus.available);
      await tester.pumpAndSettle();
      users.ack = Completer<void>();
      await tester.tap(save);
      await tester.pump();
      expect(store.data['test-user']!.name, 'Ana');
      users.ack!.complete();
      await tester.pumpAndSettle();
      expect(store.data, isEmpty);
      expect(users.profiles['test-user']!.name, 'Ana');
      await tester.pumpWidget(const SizedBox.shrink());
      network.dispose();
    },
  );
}
