class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.preferredCategoryId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String gender;
  final int age;
  final String preferredCategoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class UserProfileUpdate {
  const UserProfileUpdate({
    required this.name,
    required this.gender,
    required this.age,
    required this.preferredCategoryId,
  });

  final String name;
  final String gender;
  final int age;
  final String preferredCategoryId;
}
