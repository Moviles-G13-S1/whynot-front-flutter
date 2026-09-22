import 'user_profile.dart';

abstract interface class UserRepository {
  Stream<UserProfile?> watch(String userId);
  Stream<List<UserProfile>> watchAll();
  Future<UserProfile?> get(String userId);
  Future<void> create(UserProfile profile);
  Future<void> update(String userId, UserProfileUpdate update);
}
