import 'package:firebase_auth/firebase_auth.dart';

enum AdminAccess { admin, regularUser, signedOut }

typedef AdminAccessResolver = Future<AdminAccess> Function();

/// Resolves the administrative role from the signed Firebase ID token.
abstract final class AdminAuthorization {
  static bool hasAdminClaim(Map<Object?, Object?>? claims) {
    return claims?['admin'] == true;
  }

  /// Forces a refresh so newly granted or revoked claims take effect before
  /// an administrative route is displayed.
  static Future<AdminAccess> resolve() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return AdminAccess.signedOut;
    }

    final token = await user.getIdTokenResult(true);
    return hasAdminClaim(token.claims)
        ? AdminAccess.admin
        : AdminAccess.regularUser;
  }
}
