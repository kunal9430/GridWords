import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Controls the SCREEN's actual backlight brightness while this app is
/// open — distinct from the light/dark color THEME. Uses
/// setApplicationScreenBrightness, which only affects this app's window;
/// the device's system-wide brightness (and every other app) is
/// untouched, and Android automatically restores the system level the
/// moment the user leaves the app.
class BrightnessController {
  BrightnessController._internal();
  static final BrightnessController instance = BrightnessController._internal();

  /// null = following the system brightness (override disabled).
  final ValueNotifier<double?> level = ValueNotifier<double?>(null);

  static const String _enabledKey = 'brightness_override_enabled';
  static const String _levelKey = 'brightness_override_level';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final saved = prefs.getDouble(_levelKey) ?? 0.7;
    if (enabled) {
      level.value = saved;
      try {
        await ScreenBrightness().setApplicationScreenBrightness(saved);
      } catch (_) {
        // Not fatal — some devices/emulators don't support this API.
      }
    }
  }

  Future<void> setLevel(double value) async {
    level.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setDouble(_levelKey, value);
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (_) {
      // Ignore — slider still reflects the chosen value even if the
      // platform call fails on this device.
    }
  }

  Future<void> resetToSystem() async {
    level.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Ignore.
    }
  }
}
