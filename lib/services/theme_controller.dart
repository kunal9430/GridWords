import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// App-wide theme/appearance settings holder. Every setting is exposed as
/// a [ValueNotifier] so any widget can listen and rebuild automatically,
/// and every setting is persisted locally so it survives app restarts.
class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  // Index into AppTheme.lightThemes / AppTheme.darkThemes. Kept separate
  // per-mode so switching Light<->Dark never silently loses the other
  // mode's chosen color.
  final ValueNotifier<int> lightThemeIndex = ValueNotifier<int>(0);
  final ValueNotifier<int> darkThemeIndex = ValueNotifier<int>(0);

  // null means "platform default font".
  final ValueNotifier<String?> fontFamily = ValueNotifier<String?>(null);

  // Multiplier applied to every text style app-wide, e.g. 0.85x - 1.3x.
  final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);

  static const String _modeKey = 'theme_mode_preference';
  static const String _lightIndexKey = 'theme_light_color_index';
  static const String _darkIndexKey = 'theme_dark_color_index';
  static const String _fontFamilyKey = 'theme_font_family';
  static const String _fontScaleKey = 'theme_font_scale';

  Color get currentLightSeed => AppTheme.lightThemes[lightThemeIndex.value].seed;
  Color get currentDarkSeed => AppTheme.darkThemes[darkThemeIndex.value].seed;

  /// Call once at app startup to restore every saved preference.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    switch (prefs.getString(_modeKey)) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }

    final savedLightIndex = prefs.getInt(_lightIndexKey);
    if (savedLightIndex != null && savedLightIndex >= 0 && savedLightIndex < AppTheme.lightThemes.length) {
      lightThemeIndex.value = savedLightIndex;
    }
    final savedDarkIndex = prefs.getInt(_darkIndexKey);
    if (savedDarkIndex != null && savedDarkIndex >= 0 && savedDarkIndex < AppTheme.darkThemes.length) {
      darkThemeIndex.value = savedDarkIndex;
    }
    fontFamily.value = prefs.getString(_fontFamilyKey);
    final savedScale = prefs.getDouble(_fontScaleKey);
    if (savedScale != null) fontScale.value = savedScale;
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
    await prefs.setString(_modeKey, value);

    // Choosing "System" always means "go back to the classic default
    // look" — not just for the current session (main.dart already forces
    // that visually) but as a real, persisted reset. So the next time the
    // player switches to an explicit Light or Dark mode, they land back
    // on "Classic (Default)" instead of silently reappearing on whatever
    // custom swatch was picked before.
    if (mode == ThemeMode.system) {
      await setLightThemeIndex(0);
      await setDarkThemeIndex(0);
    }
  }

  /// Flips between light and dark, resolving "system" to whatever the
  /// device is currently showing before toggling away from it.
  void toggleLightDark(Brightness platformBrightness) {
    final isCurrentlyDark = themeMode.value == ThemeMode.dark ||
        (themeMode.value == ThemeMode.system && platformBrightness == Brightness.dark);
    setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLightThemeIndex(int index) async {
    lightThemeIndex.value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lightIndexKey, index);
  }

  Future<void> setDarkThemeIndex(int index) async {
    darkThemeIndex.value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_darkIndexKey, index);
  }

  Future<void> setFontFamily(String? family) async {
    fontFamily.value = family;
    final prefs = await SharedPreferences.getInstance();
    if (family == null) {
      await prefs.remove(_fontFamilyKey);
    } else {
      await prefs.setString(_fontFamilyKey, family);
    }
  }

  Future<void> setFontScale(double scale) async {
    fontScale.value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, scale);
  }
}
