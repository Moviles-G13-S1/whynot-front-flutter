import '../models/user_profile.dart';
import '../models/repositories/user_repository.dart';
import '../models/repositories/auth_repository.dart';
import '../models/auth_user.dart';
import '../models/input_policy.dart';
import 'connectivity_status.dart';

class AuthController {
  const AuthController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    this.onAuthChanged,
    this.connectivity,
    this.onSessionEnded,
  }) : _authRepository = authRepository,
       _userRepository = userRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final void Function()? onAuthChanged;
  final ConnectivityStatus? connectivity;
  final Future<void> Function(String userId)? onSessionEnded;

  Future<void> _requireNetwork() async {
    if (connectivity != null && !await connectivity!.canAttemptNetwork()) {
      throw const AuthFailure('network-request-failed');
    }
  }

  AuthUser? get currentUser => _authRepository.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    final previousId = currentUser?.id;
    await _requireNetwork();
    InputPolicy.noEmoji(email, 'Email');
    InputPolicy.noEmoji(password, 'Password');
    await _authRepository.signIn(email: email, password: password);
    // Santiago Casasbuenas: Do not reuse another session's recommendation.
    onAuthChanged?.call();
    if (previousId != null && previousId != currentUser?.id) {
      await onSessionEnded?.call(previousId);
    }
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required String gender,
    required int age,
    required String preferredCategoryId,
    required String cityId,
  }) async {
    await _requireNetwork();
    InputPolicy.noEmoji(name, 'Name');
    InputPolicy.noEmoji(email, 'Email');
    InputPolicy.noEmoji(password, 'Password');
    if (password.length < InputPolicy.minimumPasswordLength) {
      throw const AuthFailure('weak-password');
    }
    if (name.trim().isEmpty ||
        name.trim().length > UserProfileConstraints.maximumNameLength) {
      throw const AuthFailure('invalid-name');
    }
    if (age < UserProfileConstraints.minimumAge ||
        age > UserProfileConstraints.maximumAge) {
      throw const AuthFailure('invalid-age');
    }

    final previousId = currentUser?.id;
    final user = await _authRepository.createUser(
      email: email,
      password: password,
    );
    onAuthChanged?.call();
    if (previousId != null && previousId != user.id) {
      await onSessionEnded?.call(previousId);
    }
    try {
      await _userRepository.create(
        UserProfile(
          id: user.id,
          name: name,
          email: email,
          gender: gender,
          age: age,
          preferredCategoryId: preferredCategoryId,
          cityId: cityId,
        ),
      );
    } catch (error, stackTrace) {
      // Avoid leaving an Authentication-only account when profile creation
      // is rejected by Firestore or interrupted by another failure.
      try {
        await _authRepository.deleteCurrentUser();
      } catch (_) {
        // Preserve the profile-creation error shown to the user.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    final userId = currentUser?.id;
    await _authRepository.signOut();
    // Santiago Casasbuenas: Discard recommendation data after sign-out.
    onAuthChanged?.call();
    if (userId != null) await onSessionEnded?.call(userId);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _requireNetwork();
    InputPolicy.noEmoji(currentPassword, 'Current password');
    InputPolicy.noEmoji(newPassword, 'New password');
    if (newPassword.length < InputPolicy.minimumPasswordLength) {
      throw const AuthFailure('weak-password');
    }
    return _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
