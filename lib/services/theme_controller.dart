import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode holder. The current mode is exposed as a
/// [ValueNotifier] so any widget (e.g. the root MaterialApp, or a toggle
/// button on the Home screen) can listen and rebuild automatically.
/// The chosen mode is persisted locally so it survives app restarts.
class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _prefsKey = 'theme_mode_preference';

  /// Call once at app startup to restore the user's saved preference.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    final String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await prefs.setString(_prefsKey, value);
  }

  /// Flips between light and dark, resolving "system" to whatever the
  /// device is currently showing before toggling away from it.
  void toggleLightDark(Brightness platformBrightness) {
    final isCurrentlyDark = themeMode.value == ThemeMode.dark ||
        (themeMode.value == ThemeMode.system && platformBrightness == Brightness.dark);
    setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
