import 'dart:typed_data';

import '../models/profile_photo.dart';
import '../models/repositories/profile_photo_repository.dart';
import '../models/repositories/auth_repository.dart';
import '../models/user_profile.dart';
import '../models/repositories/user_repository.dart';

class ProfileController {
  const ProfileController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required ProfilePhotoRepository photoRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _photoRepository = photoRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ProfilePhotoRepository _photoRepository;

  String? get currentUserId => _authRepository.currentUser?.id;
  String? get currentUserEmail => _authRepository.currentUser?.email;

  Stream<UserProfile?> watchCurrentProfile() {
    final id = currentUserId;
    return id == null ? Stream.value(null) : _userRepository.watch(id);
  }

  // Used only by the guarded admin demographic screen.
  Stream<List<UserProfile>> watchAllProfiles() => _userRepository.watchAll();

  Future<UserProfile?> getCurrentProfile() {
    final id = currentUserId;
    return id == null ? Future.value() : _userRepository.get(id);
  }

  // Santiago Casasbuenas: Select a profile image through the injected photo repository.
  Future<ProfilePhoto?> pickPhoto() => _photoRepository.pick();

  // Santiago Casasbuenas: Read only the signed-in user's stored profile image.
  Future<Uint8List?> readPhoto(String path) {
    final id = currentUserId;
    if (id == null || !path.startsWith('profilePhotos/$id/')) {
      throw StateError('Photo does not belong to the current user.');
    }
    return _photoRepository.read(path);
  }

  // Santiago Casasbuenas: Upload, save the path, and clean up replaced or failed uploads.
  Future<String> savePhoto(ProfilePhoto photo) async {
    final id = currentUserId;
    if (id == null) throw StateError('No user logged in.');
    final previous = (await _userRepository.get(id))?.photoPath;
    final path = await _photoRepository.upload(id, photo);
    try {
      await _userRepository.updatePhotoPath(id, path);
    } catch (_) {
      try {
        await _photoRepository.delete(path);
      } catch (_) {
        /* Preserve original error. */
      }
      rethrow;
    }
    if (previous != null && previous.startsWith('profilePhotos/$id/')) {
      try {
        await _photoRepository.delete(previous);
      } catch (_) {
        /* Old file can be cleaned up later. */
      }
    }
    return path;
  }

  Future<void> updateCurrentProfile(UserProfileUpdate update) {
    final id = currentUserId;
    if (id == null) throw StateError('No user logged in.');
    if (update.name.trim().isEmpty ||
        update.name.trim().length > UserProfileConstraints.maximumNameLength) {
      throw ArgumentError.value(update.name, 'name', 'Invalid profile name.');
    }
    if (update.age < UserProfileConstraints.minimumAge ||
        update.age > UserProfileConstraints.maximumAge) {
      throw ArgumentError.value(update.age, 'age', 'Invalid profile age.');
    }
    return _userRepository.update(id, update);
  }
}
