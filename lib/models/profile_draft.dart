import 'dart:convert';

/// Editable text only. Email, passwords, auth tokens and photos are excluded.
class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.ageText,
    required this.gender,
    required this.categoryId,
    required this.cityId,
    required this.cityText,
  });
  final String name, ageText, cityText;
  final String? gender, categoryId, cityId;

  String encode(String userId) {
    final payload = jsonEncode({
      'version': 1,
      'userId': userId,
      'name': name,
      'ageText': ageText,
      'gender': gender,
      'categoryId': categoryId,
      'cityId': cityId,
      'cityText': cityText,
    });
    if (decode(payload, userId) == null) {
      throw const FormatException(
        'Draft fields exceed the local storage limits.',
      );
    }
    return payload;
  }

  static ProfileDraft? decode(String payload, String userId) {
    try {
      if (payload.length > 16384) return null;
      final value = jsonDecode(payload);
      if (value is! Map || value['version'] != 1 || value['userId'] != userId) {
        return null;
      }
      for (final key in ['name', 'ageText', 'cityText']) {
        if (value[key] is! String || (value[key] as String).length > 1024) {
          return null;
        }
      }
      for (final key in ['gender', 'categoryId', 'cityId']) {
        if (value[key] != null &&
            (value[key] is! String || (value[key] as String).length > 128)) {
          return null;
        }
      }
      return ProfileDraft(
        name: value['name'] as String,
        ageText: value['ageText'] as String,
        gender: value['gender'] as String?,
        categoryId: value['categoryId'] as String?,
        cityId: value['cityId'] as String?,
        cityText: value['cityText'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
