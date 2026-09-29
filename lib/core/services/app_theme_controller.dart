import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';

class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  static Future<void> load() async {
    final raw = await AuthSession.getThemeMode();
    themeMode.value = _parse(raw);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await AuthSession.setThemeMode(_serialize(mode));
  }

  static ThemeMode _parse(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
