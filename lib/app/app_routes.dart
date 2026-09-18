/// Route names used by the application.
///
/// Keeping them in one place prevents string duplication without introducing a
/// routing package while the navigation flow is still small.
abstract final class AppRoutes {
  static const login = '/login';
  static const createAccount = '/create-account';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const changePassword = '/change-password';
}
