import '../models/profile_photo.dart';
import '../models/repositories/profile_photo_repository.dart';
import '../models/repositories/auth_repository.dart';
import '../models/user_profile.dart';
import '../models/input_policy.dart';
import '../models/repositories/user_repository.dart';
import '../models/network_failure.dart';
import 'connectivity_status.dart';
import 'dart:typed_data';
import 'profile_photo_cache.dart';
import 'application_error_reporter.dart';

class ProfileController {
  const ProfileController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required ProfilePhotoRepository photoRepository,
    this.onRecommendationInputsChanged,
    this.connectivity,
    this.photoCache,
    this.errorReporter,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _photoRepository = photoRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ProfilePhotoRepository _photoRepository;
  final void Function(String userId)? onRecommendationInputsChanged;
  final ConnectivityStatus? connectivity;
  final ProfilePhotoCache? photoCache;
  final ApplicationErrorReporter? errorReporter;

  Future<T> _track<T>(String operation, Future<T> Function() action) =>
      errorReporter?.run(
        feature: 'profile',
        operation: operation,
        action: action,
      ) ??
      action();

  Future<void> _requireNetwork() async {
    if (connectivity != null && !await connectivity!.canAttemptNetwork()) {
      throw const NetworkFailure();
    }
  }

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
    return id == null
        ? Future.value()
        : _track(
            'load_profile',
            () => _userRepository.get(id).timeout(const Duration(seconds: 12)),
          );
  }

  // Santiago Casasbuenas: Select a profile image through the injected photo repository.
  Future<ProfilePhoto?> pickPhoto() => _photoRepository.pick();

  // Santiago Casasbuenas: Resolve only the signed-in user's stored profile image.
  Future<String> getPhotoUrl(String path) {
    final id = currentUserId;
    if (id == null || !path.startsWith('profilePhotos/$id/')) {
      throw StateError('Photo does not belong to the current user.');
    }
    if (connectivity?.isOffline == true) {
      return Future.error(const NetworkFailure());
    }
    return _track(
      'load_photo',
      () => _photoRepository
          .getDownloadUrl(path)
          .timeout(const Duration(seconds: 12)),
    );
  }

  Future<Uint8List?> getPhotoBytes(String path) {
    final id = currentUserId;
    if (id == null || !path.startsWith('profilePhotos/$id/')) {
      throw StateError('Photo does not belong to the current user.');
    }
    return photoCache?.load(
          id,
          path,
          allowNetwork: connectivity?.isOffline != true,
        ) ??
        Future.value(null);
  }

  // Santiago Casasbuenas: Upload, save the path, and clean up replaced or failed uploads.
  Future<String> savePhoto(ProfilePhoto photo) =>
      _track('save_photo', () async {
        await _requireNetwork();
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
        await photoCache?.remember(id, path, photo.bytes);
        if (previous != null && previous.startsWith('profilePhotos/$id/')) {
          try {
            await _photoRepository.delete(previous);
          } catch (_) {
            /* Old file can be cleaned up later. */
          }
        }
        return path;
      });

  Future<void> updateCurrentProfile(
    UserProfileUpdate update,
  ) => _track('update_profile', () async {
    await _requireNetwork();
    InputPolicy.noEmoji(update.name, 'Name');
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
    await _userRepository.update(id, update);
    // Santiago Casasbuenas: Age, gender, and category affect matching.
    onRecommendationInputsChanged?.call(id);
  });
}
