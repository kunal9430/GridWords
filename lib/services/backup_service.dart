import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';
import 'brightness_controller.dart';
import 'profile_service.dart';
import 'storage_service.dart';
import 'theme_controller.dart';

/// Everything a restore actually changed, so the UI can tell the player
/// something honest ("3 saved games restored") instead of a generic
/// "Done!".
class BackupSummary {
  final int restoredGames;
  final bool restoredProfile;
  final String? exportedAt;
  const BackupSummary({required this.restoredGames, required this.restoredProfile, this.exportedAt});
}

/// Bundles the player's profile, appearance settings, and every saved
/// match into a single JSON file the player can export and later
/// restore — a stand-in for real cloud sign-in/sync until that exists.
///
/// The file is written wherever the OS Share sheet lets the player put
/// it (Google Drive, Files/Downloads, email, etc.) via [shareBackup];
/// restoring reads it back from wherever the player picks it via
/// [restoreFromFile]. This deliberately avoids writing to a fixed,
/// guessed device path or requesting broad storage permissions — modern
/// Android's scoped storage means an app can't silently discover an
/// arbitrary file elsewhere on the device anyway, so a real file picker
/// is both the more honest and the more reliable choice.
class BackupService {
  static const String _appId = 'grid_word_game';
  static const int _formatVersion = 1;

  static Future<Map<String, dynamic>> _buildPayload() async {
    final profile = await ProfileService.loadProfile();
    final games = await StorageService.loadAllGames();
    final controller = ThemeController.instance;
    final brightness = BrightnessController.instance;

    return {
      'app': _appId,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': {
        'name': profile.name,
        'email': profile.email,
        'photoBase64': profile.photoBase64,
      },
      'theme': {
        'mode': controller.themeMode.value.name,
        'lightIndex': controller.lightThemeIndex.value,
        'darkIndex': controller.darkThemeIndex.value,
        'fontFamily': controller.fontFamily.value,
        'fontScale': controller.fontScale.value,
      },
      'brightness': {
        'level': brightness.level.value,
      },
      'games': games.map((g) => g.toJson()).toList(),
    };
  }

  /// Writes the backup JSON to a temp file and returns it, ready to hand
  /// to the Share sheet.
  static Future<File> _writeTempBackupFile() async {
    final payload = await _buildPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final fileName = 'gridwords_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(jsonStr);
  }

  /// Builds the backup file and opens the system Share sheet so the
  /// player can save it to Drive, Files, email it to themselves, etc.
  static Future<void> shareBackup() async {
    final file = await _writeTempBackupFile();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Grid Words Backup',
      text: 'Grid Words backup file — keep this safe and use "Restore Backup" in Settings to bring your '
          'profile and saved games back after reinstalling.',
    );
  }

  static Future<BackupSummary> restoreFromFile(File file) async {
    final content = await file.readAsString();
    return restoreFromJsonString(content);
  }

  static Future<BackupSummary> restoreFromJsonString(String content) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This file is not a valid Grid Words backup.');
    }
    if (decoded['app'] != _appId) {
      throw const FormatException('This does not look like a Grid Words backup file.');
    }

    bool restoredProfile = false;
    final profileJson = decoded['profile'];
    if (profileJson is Map<String, dynamic>) {
      await ProfileService.saveProfile(Profile(
        name: profileJson['name'] as String? ?? '',
        email: profileJson['email'] as String? ?? '',
        photoBase64: profileJson['photoBase64'] as String?,
      ));
      restoredProfile = true;
    }

    final themeJson = decoded['theme'];
    if (themeJson is Map<String, dynamic>) {
      final controller = ThemeController.instance;
      ThemeMode mode;
      switch (themeJson['mode'] as String?) {
        case 'light':
          mode = ThemeMode.light;
          break;
        case 'dark':
          mode = ThemeMode.dark;
          break;
        default:
          mode = ThemeMode.system;
      }
      final lightIdx = (themeJson['lightIndex'] as num?)?.toInt();
      if (lightIdx != null && lightIdx >= 0 && lightIdx < AppTheme.lightThemes.length) {
        await controller.setLightThemeIndex(lightIdx);
      }
      final darkIdx = (themeJson['darkIndex'] as num?)?.toInt();
      if (darkIdx != null && darkIdx >= 0 && darkIdx < AppTheme.darkThemes.length) {
        await controller.setDarkThemeIndex(darkIdx);
      }
      // Applied last and on purpose: if the backup's mode was "System",
      // setThemeMode resets the two indices above back to classic — the
      // same "System always means classic" rule the rest of the app
      // follows, so a restore never behaves differently from picking
      // System by hand.
      await controller.setThemeMode(mode);
      await controller.setFontFamily(themeJson['fontFamily'] as String?);
      final scale = (themeJson['fontScale'] as num?)?.toDouble();
      if (scale != null) await controller.setFontScale(scale);
    }

    final brightnessJson = decoded['brightness'];
    if (brightnessJson is Map<String, dynamic>) {
      final level = (brightnessJson['level'] as num?)?.toDouble();
      if (level != null) {
        await BrightnessController.instance.setLevel(level);
      }
    }

    int restoredGames = 0;
    final gamesJson = decoded['games'];
    if (gamesJson is List) {
      for (final g in gamesJson) {
        if (g is! Map<String, dynamic>) continue;
        try {
          final game = GameState.fromJson(g);
          await StorageService.saveGame(game);
          restoredGames++;
        } catch (_) {
          // Skip any single corrupted entry rather than aborting the
          // whole restore over one bad record.
        }
      }
    }

    return BackupSummary(
      restoredGames: restoredGames,
      restoredProfile: restoredProfile,
      exportedAt: decoded['exportedAt'] as String?,
    );
  }

  /// Best-effort signal used right after install: true only when this
  /// device has no local profile AND no saved games yet, meaning it's
  /// worth asking whether the player has a backup file to bring in.
  /// Returning players who already have data are never interrupted.
  static Future<bool> looksLikeFreshInstall() async {
    final profileEmpty = await ProfileService.isProfileEmpty();
    if (!profileEmpty) return false;
    final games = await StorageService.loadAllGames();
    return games.isEmpty;
  }
}
