/// Validation shared by controller entry points and forms. Existing stored text
/// is never changed while reading; the policy applies when writing new values.
class InputPolicyException implements Exception {
  const InputPolicyException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InputPolicy {
  InputPolicy._();

  static const int minimumPasswordLength = 8;

  // Includes supplementary emoji, pictographs, regional indicators, modifiers,
  // keycap marks and text symbols explicitly rendered as emoji with VS16.
  static final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{20E3}]|[\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}\u{2194}-\u{21AA}\u{231A}-\u{23FA}\u{24C2}\u{25AA}-\u{25FE}\u{2934}-\u{2935}\u{2B05}-\u{2B55}]\u{FE0F}',
    unicode: true,
  );

  static bool containsEmoji(String value) => _emoji.hasMatch(value);

  static void noEmoji(String value, String field) {
    if (containsEmoji(value)) {
      throw InputPolicyException('$field cannot contain emoji.');
    }
  }

  static String? nameValidationError(String value, {required int maxLength}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required.';
    if (containsEmoji(trimmed)) {
      return 'You cannot include emojis in your name.';
    }
    if (trimmed.length > maxLength) {
      return 'Name cannot exceed $maxLength characters.';
    }
    return null;
  }

  static String? emailValidationError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required.';
    if (containsEmoji(trimmed)) {
      return 'You cannot include emojis in your email.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? passwordValidationError(
    String value, {
    bool requireMinimumLength = false,
  }) {
    if (value.isEmpty) return 'Password is required.';
    if (containsEmoji(value)) {
      return 'You cannot include emojis in your password.';
    }
    if (requireMinimumLength && value.length < minimumPasswordLength) {
      return 'Password must be at least $minimumPasswordLength characters.';
    }
    return null;
  }

  /// Optional web URL. Uri parsing alone accepts Unicode and relative paths.
  static bool isOptionalWebUrl(String value) {
    if (value.isEmpty) return true;
    if (containsEmoji(value) || RegExp(r'\s').hasMatch(value)) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.host.contains('.') || uri.host == 'localhost');
  }

  static void optionalWebUrl(String value, String field) {
    if (!isOptionalWebUrl(value)) {
      throw InputPolicyException('$field must be a valid http or https URL.');
    }
  }
}
