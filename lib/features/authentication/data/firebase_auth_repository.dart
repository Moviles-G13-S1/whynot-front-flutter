import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AuthUser(id: user.uid, email: user.email);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthFailure('no-current-user');
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  @override
  Future<Map<Object?, Object?>> refreshedClaims() async {
    final user = _auth.currentUser;
    if (user == null) return const {};

    try {
      final token = await user.getIdTokenResult(true);
      return token.claims ?? const {};
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, error);
    }
  }

  AuthUser _requireUser(User? user) {
    if (user == null) throw const AuthFailure('missing-user');
    return AuthUser(id: user.uid, email: user.email);
  }
}
