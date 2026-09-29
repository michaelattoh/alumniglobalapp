import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _previewAlumniKey = 'preview_as_alumni';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricRoleKey = 'biometric_role';
  static const _pinHashKey = 'biometric_pin_hash';
  static const _pinSaltKey = 'biometric_pin_salt';
  static const _biometricLogoutKey = 'biometric_logged_out';
  static const _roleKey = 'auth_role';
  static const _notificationSoundEnabledKey = 'notification_sound_enabled';
  static const _themeModeKey = 'theme_mode';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, id);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }

  static Future<void> setPreviewAsAlumni(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_previewAlumniKey, enabled);
  }

  static Future<bool> getPreviewAsAlumni() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_previewAlumniKey) ?? false;
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> getBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> setBiometricRole(String? role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == null || role.isEmpty) {
      await prefs.remove(_biometricRoleKey);
    } else {
      await prefs.setString(_biometricRoleKey, role);
    }
  }

  static Future<String?> getBiometricRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_biometricRoleKey);
  }

  static Future<void> setBiometricLoggedOut(bool loggedOut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricLogoutKey, loggedOut);
  }

  static Future<bool> consumeBiometricLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_biometricLogoutKey) ?? false;
    if (flag) {
      await prefs.remove(_biometricLogoutKey);
    }
    return flag;
  }

  static Future<void> setNotificationSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundEnabledKey, enabled);
  }

  static Future<bool> getNotificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationSoundEnabledKey) ?? true;
  }

  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'light';
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await prefs.setString(_pinSaltKey, salt);
    await prefs.setString(_pinHashKey, hash);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_pinSaltKey);
    final hash = prefs.getString(_pinHashKey);
    if (salt == null || hash == null) return false;
    return _hashPin(pin, salt) == hash;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinSaltKey);
  }

  static String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPin(String pin, String salt) {
    final data = utf8.encode('$salt:$pin');
    return sha256.convert(data).toString();
  }
}
