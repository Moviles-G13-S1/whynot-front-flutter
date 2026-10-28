import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/controllers/profile_photo_cache.dart';
import 'package:whynot_mobile/controllers/auth_controller.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/profile_controller.dart';
import 'package:whynot_mobile/infrastructure/repositories/profile_photo_cache_stores.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/profile_photo.dart';
import 'package:whynot_mobile/models/repositories/profile_photo_cache_store.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/widgets/profile_controls.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

final imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4H0AAAAASUVORK5CYII=',
);
const alicePath = 'profilePhotos/alice/old.png';
const newPath = 'profilePhotos/alice/new.png';

class MemoryPhotoStore implements ProfilePhotoCacheStore {
  final rows = <String, ({String path, Uint8List bytes})>{};
  @override
  Future<Uint8List?> read(String userId, String path) async =>
      rows[userId]?.path == path ? rows[userId]?.bytes : null;
  @override
  Future<void> write(String userId, String path, Uint8List bytes) async {
    rows[userId] = (path: path, bytes: bytes);
  }

  @override
  Future<void> clear(String userId) async {
    rows.remove(userId);
  }
}

class RejectPhotoUsers extends InMemoryUserRepository {
  @override
  Future<void> updatePhotoPath(String userId, String path) async =>
      throw StateError('write rejected');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test(
    'first online load downloads once; offline reads bytes, not URL',
    () async {
      final store = MemoryPhotoStore();
      var downloads = 0;
      final cache = ProfilePhotoCache(
        store: store,
        currentUserId: () => 'alice',
        download: (_) async {
          downloads++;
          return imageBytes;
        },
      );
      expect(
        await cache.load('alice', alicePath, allowNetwork: true),
        imageBytes,
      );
      expect(
        await cache.load('alice', alicePath, allowNetwork: false),
        imageBytes,
      );
      expect(downloads, 1);
      // Simulate a new app/cache controller with the same persistent store.
      final restarted = ProfilePhotoCache(
        store: store,
        currentUserId: () => 'alice',
        download: (_) async => throw StateError('offline'),
      );
      expect(
        await restarted.load('alice', alicePath, allowNetwork: false),
        imageBytes,
      );
    },
  );

  test('offline miss is empty and can recover after reconnection', () async {
    var downloads = 0;
    final cache = ProfilePhotoCache(
      store: MemoryPhotoStore(),
      currentUserId: () => 'alice',
      download: (_) async {
        downloads++;
        return imageBytes;
      },
    );
    expect(await cache.load('alice', alicePath, allowNetwork: false), isNull);
    expect(downloads, 0);
    expect(
      await cache.load('alice', alicePath, allowNetwork: true),
      imageBytes,
    );
    expect(downloads, 1);
  });

  test('concurrent avatars coalesce one download', () async {
    final pending = Completer<Uint8List?>();
    var downloads = 0;
    final cache = ProfilePhotoCache(
      store: MemoryPhotoStore(),
      currentUserId: () => 'alice',
      download: (_) {
        downloads++;
        return pending.future;
      },
    );
    final a = cache.load('alice', alicePath, allowNetwork: true);
    final b = cache.load('alice', alicePath, allowNetwork: true);
    await Future<void>.delayed(Duration.zero);
    expect(downloads, 1);
    pending.complete(imageBytes);
    expect(await a, imageBytes);
    expect(await b, imageBytes);
  });

  test('a newer path supersedes a pending old download', () async {
    final store = MemoryPhotoStore();
    final pending = Completer<Uint8List?>();
    final cache = ProfilePhotoCache(
      store: store,
      currentUserId: () => 'alice',
      download: (_) => pending.future,
    );
    final old = cache.load('alice', alicePath, allowNetwork: true);
    await Future<void>.delayed(Duration.zero);
    await cache.remember('alice', newPath, imageBytes);
    pending.complete(Uint8List.fromList([1, 2]));
    expect(await old, isNull);
    expect(store.rows['alice']!.path, newPath);
    expect(await cache.load('alice', newPath, allowNetwork: false), imageBytes);
  });

  test(
    'sign-out erases cache and a late download cannot repopulate it',
    () async {
      String? current = 'alice';
      final store = MemoryPhotoStore();
      final pending = Completer<Uint8List?>();
      final cache = ProfilePhotoCache(
        store: store,
        currentUserId: () => current,
        download: (_) => pending.future,
      );
      final request = cache.load('alice', alicePath, allowNetwork: true);
      await Future<void>.delayed(Duration.zero);
      current = null;
      await cache.clear('alice');
      pending.complete(imageBytes);
      expect(await request, isNull);
      expect(store.rows, isEmpty);
    },
  );

  test(
    'owner and exact path are required; switching users never returns old bytes',
    () async {
      String? current = 'alice';
      final cache = ProfilePhotoCache(
        store: MemoryPhotoStore(),
        currentUserId: () => current,
        download: (_) async => imageBytes,
      );
      await cache.remember('alice', alicePath, imageBytes);
      current = 'bob';
      expect(await cache.load('alice', alicePath, allowNetwork: false), isNull);
      expect(
        () => cache.load('bob', alicePath, allowNetwork: true),
        throwsStateError,
      );
      expect(
        await cache.load(
          'bob',
          'profilePhotos/bob/avatar.png',
          allowNetwork: false,
        ),
        isNull,
      );
    },
  );

  test(
    'SQLite bytes survive closing/reopening and retain one path per owner',
    () async {
      final directory = await Directory.systemTemp.createTemp('whynot-avatar-');
      final path = '${directory.path}/avatars.db';
      var store = SqliteProfilePhotoCacheStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      try {
        await store.write('alice', alicePath, imageBytes);
        await store.write('bob', 'profilePhotos/bob/avatar.png', imageBytes);
        await store.close();
        store = SqliteProfilePhotoCacheStore(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        expect(await store.read('alice', alicePath), imageBytes);
        expect(await store.read('bob', alicePath), isNull);
        await store.write('alice', newPath, imageBytes);
        expect(await store.read('alice', alicePath), isNull);
        expect(await store.read('alice', newPath), imageBytes);
        await store.clear('alice');
        expect(await store.read('alice', newPath), isNull);
        expect(
          await store.read('bob', 'profilePhotos/bob/avatar.png'),
          imageBytes,
        );
      } finally {
        await store.close();
        await File(path).delete();
        await directory.delete();
      }
    },
  );

  test(
    'AuthController clears the signed-out owner through the cache hook',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      );
      final store = MemoryPhotoStore();
      final cache = ProfilePhotoCache(
        store: store,
        currentUserId: () => auth.currentUser?.id,
        download: (_) async => imageBytes,
      );
      await cache.remember('alice', alicePath, imageBytes);
      await AuthController(
        authRepository: auth,
        userRepository: InMemoryUserRepository(),
        onSessionEnded: cache.clear,
      ).signOut();
      expect(auth.currentUser, isNull);
      expect(store.rows, isEmpty);
    },
  );

  test(
    'confirmed upload replaces local bytes; rejected upload retains previous cache',
    () async {
      final auth = InMemoryAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      );
      final store = MemoryPhotoStore();
      final cache = ProfilePhotoCache(
        store: store,
        currentUserId: () => auth.currentUser?.id,
        download: (_) async => throw StateError('no download needed'),
      );
      await cache.remember('alice', alicePath, imageBytes);
      const user = UserProfile(
        id: 'alice',
        name: 'Alice',
        email: 'alice@example.com',
        gender: 'Female',
        age: 22,
        preferredCategoryId: 'fashion',
        photoPath: alicePath,
      );
      final rejectedUsers = RejectPhotoUsers()..profiles['alice'] = user;
      final photo = ProfilePhoto(
        bytes: imageBytes,
        contentType: 'image/png',
        extension: 'png',
      );
      final rejected = ProfileController(
        authRepository: auth,
        userRepository: rejectedUsers,
        photoRepository: InMemoryProfilePhotoRepository(),
        photoCache: cache,
      );
      await expectLater(rejected.savePhoto(photo), throwsStateError);
      expect(store.rows['alice']!.path, alicePath);
      final users = InMemoryUserRepository()..profiles['alice'] = user;
      final controller = ProfileController(
        authRepository: auth,
        userRepository: users,
        photoRepository: InMemoryProfilePhotoRepository(),
        photoCache: cache,
      );
      final savedPath = await controller.savePhoto(photo);
      expect(store.rows['alice']!.path, savedPath);
      expect(await store.read('alice', alicePath), isNull);
      expect(await controller.getPhotoBytes(savedPath), imageBytes);
    },
  );

  testWidgets(
    'cached avatar renders MemoryImage offline without resolving a URL',
    (tester) async {
      final connection = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.offline);
      var urlCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              photoPath: alicePath,
              connectivity: connection,
              loadPhotoBytes: (_) async => imageBytes,
              loadPhotoUrl: (_) async {
                urlCalls++;
                throw StateError('offline');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      expect(urlCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    },
  );
}
