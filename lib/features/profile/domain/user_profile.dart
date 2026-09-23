abstract final class UserProfileConstraints {
  static const int minimumAge = 13;
  static const int maximumAge = 120;
  static const int maximumNameLength = 15;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.preferredCategoryId,
    this.cityId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String gender;
  final int age;
  final String preferredCategoryId;
  final String? cityId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class UserProfileUpdate {
  const UserProfileUpdate({
    required this.name,
    required this.gender,
    required this.age,
    required this.preferredCategoryId,
    required this.cityId,
  });

  final String name;
  final String gender;
  final int age;
  final String preferredCategoryId;
  final String cityId;
}
