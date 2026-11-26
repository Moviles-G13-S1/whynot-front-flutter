import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local biometric unlock for an existing Firebase session.
/// Only the user's opt-in preference is persisted, never credentials.
class FaceIdController {
  FaceIdController({
    LocalAuthentication? authentication,
    SharedPreferencesAsync? preferences,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _preferences = preferences ?? SharedPreferencesAsync();

  final LocalAuthentication _authentication;
  final SharedPreferencesAsync _preferences;

  bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String _key(String userId) => 'face_id_enabled_$userId';

  Future<bool> isEnabled(String userId) async {
    if (!supportedPlatform) return false;
    return await _preferences.getBool(_key(userId)) ?? false;
  }

  Future<bool> isAvailable() async {
    if (!supportedPlatform) return false;
    try {
      final biometrics = await _authentication.getAvailableBiometrics();
      return biometrics.contains(BiometricType.face);
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!await isAvailable()) return false;
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock your WhyNot account with Face ID',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enable(String userId) async {
    if (!await authenticate()) return false;
    await _preferences.setBool(_key(userId), true);
    return true;
  }

  Future<void> disable(String userId) async {
    if (supportedPlatform) await _preferences.remove(_key(userId));
  }
}
