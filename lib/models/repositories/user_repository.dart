import '../user_profile.dart';

abstract interface class UserRepository {
  Stream<UserProfile?> watch(String userId);
  Stream<List<UserProfile>> watchAll();
  Future<UserProfile?> get(String userId);
  Future<void> create(UserProfile profile);
  Future<void> update(String userId, UserProfileUpdate update);
  // Santiago Casasbuenas: Save the current user's photo reference.
  Future<void> updatePhotoPath(String userId, String path);
}
