import 'auth_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.cause]);

  final String code;
  final Object? cause;
}

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  Future<void> deleteCurrentUser();

  Future<void> signOut();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Map<Object?, Object?>> refreshedClaims();
}
