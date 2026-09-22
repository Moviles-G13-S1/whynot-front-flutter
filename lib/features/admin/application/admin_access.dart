import '../../authentication/domain/auth_repository.dart';

enum AdminAccess { admin, regularUser, signedOut }

typedef AdminAccessResolver = Future<AdminAccess> Function();

class AdminAccessController {
  const AdminAccessController(this._authRepository);

  final AuthRepository _authRepository;

  Future<AdminAccess> resolve() async {
    if (_authRepository.currentUser == null) return AdminAccess.signedOut;
    final claims = await _authRepository.refreshedClaims();
    return AdminAuthorization.hasAdminClaim(claims)
        ? AdminAccess.admin
        : AdminAccess.regularUser;
  }
}

/// Pure claim check kept separate so authorization behavior is easy to test.
abstract final class AdminAuthorization {
  static bool hasAdminClaim(Map<Object?, Object?>? claims) {
    return claims?['admin'] == true;
  }
}
