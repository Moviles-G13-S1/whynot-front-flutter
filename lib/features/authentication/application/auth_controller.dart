import '../../profile/domain/user_profile.dart';
import '../../profile/domain/user_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthController {
  const AuthController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  AuthUser? get currentUser => _authRepository.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _authRepository.signIn(email: email, password: password);

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required String gender,
    required int age,
    required String preferredCategoryId,
    required String cityId,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > UserProfileConstraints.maximumNameLength) {
      throw const AuthFailure('invalid-name');
    }
    if (age < UserProfileConstraints.minimumAge ||
        age > UserProfileConstraints.maximumAge) {
      throw const AuthFailure('invalid-age');
    }

    final user = await _authRepository.createUser(
      email: email,
      password: password,
    );
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

  Future<void> signOut() => _authRepository.signOut();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _authRepository.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );
}
