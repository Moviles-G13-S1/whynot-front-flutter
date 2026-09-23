import '../../authentication/domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../domain/user_repository.dart';

class ProfileController {
  const ProfileController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;

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
