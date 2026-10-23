import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/profile_controller.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/profile_photo.dart';
import 'package:whynot_mobile/models/repositories/profile_photo_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/widgets/profile_controls.dart';

import 'fakes/in_memory_repositories.dart';

class _Photos implements ProfilePhotoRepository {
  final deleted = <String>[];
  String uploaded = 'profilePhotos/alice/123-456.jpg';
  bool pickCanceled = false;

  @override
  // Santiago Casasbuenas: Simulate a selected or canceled image.
  Future<ProfilePhoto?> pick() async => pickCanceled
      ? null
      : ProfilePhoto(
          bytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
          extension: 'jpg',
        );
  @override
  // Santiago Casasbuenas: Return a test upload path.
  Future<String> upload(String userId, ProfilePhoto photo) async => uploaded;
  @override
  // Santiago Casasbuenas: Simulate resolving a stored image.
  Future<String> getDownloadUrl(String path) async =>
      'https://example.com/profile.jpg';
  @override
  // Santiago Casasbuenas: Track cleanup of photo objects.
  Future<void> delete(String path) async => deleted.add(path);
}

class _FailingUsers extends InMemoryUserRepository {
  @override
  // Santiago Casasbuenas: Simulate a failed Firestore photo update.
  Future<void> updatePhotoPath(String userId, String path) async =>
      throw StateError('Firestore unavailable');
}

const _profile = UserProfile(
  id: 'alice',
  name: 'Alice',
  email: 'alice@example.com',
  gender: 'Female',
  age: 22,
  preferredCategoryId: 'fashion',
  photoPath: 'profilePhotos/alice/111-222.jpg',
);

// Santiago Casasbuenas: Verify profile photo behavior and avatar states.
void main() {
  test(
    'cancel leaves the profile alone; save replaces and deletes the previous image',
    () async {
      final users = InMemoryUserRepository()..profiles['alice'] = _profile;
      final photos = _Photos()..pickCanceled = true;
      final controller = ProfileController(
        authRepository: InMemoryAuthRepository(
          user: const AuthUser(id: 'alice', email: 'alice@example.com'),
        ),
        userRepository: users,
        photoRepository: photos,
      );
      expect(await controller.pickPhoto(), isNull);
      expect(users.profiles['alice']!.photoPath, _profile.photoPath);
      photos.pickCanceled = false;
      await controller.savePhoto((await controller.pickPhoto())!);
      expect(users.profiles['alice']!.photoPath, photos.uploaded);
      expect(photos.deleted, [_profile.photoPath]);
      expect(
        await controller.getPhotoUrl(photos.uploaded),
        'https://example.com/profile.jpg',
      );
      expect(
        () => controller.getPhotoUrl('profilePhotos/bob/123-456.jpg'),
        throwsStateError,
      );
    },
  );

  test('failed profile update deletes the newly uploaded image', () async {
    final users = _FailingUsers()..profiles['alice'] = _profile;
    final photos = _Photos();
    final controller = ProfileController(
      authRepository: InMemoryAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      ),
      userRepository: users,
      photoRepository: photos,
    );
    await expectLater(
      controller.savePhoto((await photos.pick())!),
      throwsStateError,
    );
    expect(photos.deleted, [photos.uploaded]);
    expect(users.profiles['alice']!.photoPath, _profile.photoPath);
  });

  testWidgets(
    'avatar uses a CORS-safe web image and supports a local preview',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              photoPath: 'profilePhotos/alice/123-456.jpg',
              loadPhotoUrl: (_) async => 'https://example.com/profile.jpg',
            ),
          ),
        ),
      );
      await tester.pump();
      final storedImage = tester.widget<Image>(find.byType(Image));
      final provider = storedImage.image as NetworkImage;
      expect(provider.webHtmlElementStrategy, WebHtmlElementStrategy.prefer);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              preview: Uint8List.fromList([
                0x89,
                0x50,
                0x4e,
                0x47,
                0x0d,
                0x0a,
                0x1a,
                0x0a,
              ]),
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
