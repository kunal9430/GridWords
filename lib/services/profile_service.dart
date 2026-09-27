import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's own saved profile details: display name (used to prefill
/// "Player 1" on the Setup screen and to greet the player on Home),
/// an optional email, and an optional profile photo.
///
/// The photo is stored as a base64-encoded JPEG string directly in
/// SharedPreferences (rather than as a separate file on disk) so it
/// travels along automatically with everything else this app already
/// persists — including inside a Backup export (see BackupService) —
/// without needing to manage a second file path that could go stale.
class Profile {
  final String name;
  final String email;
  final String? photoBase64;

  const Profile({this.name = '', this.email = '', this.photoBase64});

  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;

  Profile copyWith({String? name, String? email, String? photoBase64, bool clearPhoto = false}) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
    );
  }
}

class ProfileService {
  static const String _nameKey = 'profile_display_name';
  static const String _emailKey = 'profile_email';
  static const String _photoKey = 'profile_photo_base64';

  /// Live copy of the saved profile. Every screen that displays profile
  /// info (Home's greeting, Settings' Profile tab, ...) should read this
  /// via a ValueListenableBuilder rather than loading it once into local
  /// State, so a change made anywhere -- editing the profile, or
  /// restoring a backup -- is reflected everywhere immediately, even in
  /// screens that were already on-screen when the change happened.
  static final ValueNotifier<Profile> current = ValueNotifier<Profile>(const Profile());

  /// Loads the saved profile from disk into [current]. Call once at app
  /// startup (see main.dart) so [current] is accurate before anything
  /// reads it.
  static Future<void> init() async {
    current.value = await loadProfile();
  }

  static Future<String> loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? '';
  }

  static Future<Profile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return Profile(
      name: prefs.getString(_nameKey) ?? '',
      email: prefs.getString(_emailKey) ?? '',
      photoBase64: prefs.getString(_photoKey),
    );
  }

  /// True the very first time this device has no profile saved at all —
  /// used to decide whether to offer a fresh install a backup restore.
  static Future<bool> isProfileEmpty() async {
    final profile = await loadProfile();
    return profile.name.isEmpty && profile.email.isEmpty && !profile.hasPhoto;
  }

  static Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_nameKey, trimmed);
    }
    current.value = current.value.copyWith(name: trimmed);
  }

  static Future<void> saveProfile(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();

    final trimmedName = profile.name.trim();
    if (trimmedName.isEmpty) {
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_nameKey, trimmedName);
    }

    final trimmedEmail = profile.email.trim();
    if (trimmedEmail.isEmpty) {
      await prefs.remove(_emailKey);
    } else {
      await prefs.setString(_emailKey, trimmedEmail);
    }

    if (profile.photoBase64 == null || profile.photoBase64!.isEmpty) {
      await prefs.remove(_photoKey);
    } else {
      await prefs.setString(_photoKey, profile.photoBase64!);
    }

    current.value = Profile(name: trimmedName, email: trimmedEmail, photoBase64: profile.photoBase64);
  }
}
