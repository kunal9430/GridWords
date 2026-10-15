import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_links.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Keeps the signed-in player's name and email in the Realtime Database
/// (`users/<uid>/profile`), so a new phone or a reinstall gets the same
/// profile back after signing in with the same Google account.
///
/// The profile photo is NOT uploaded - it stays on the device (and in
/// Backups) - and everything here is best-effort: when the network is down
/// the local profile keeps working and the next sign-in or edit syncs again.
class CloudProfileService {
  CloudProfileService({http.Client? client, AuthService? auth, String? baseUrl})
      : _client = client ?? http.Client(),
        _auth = auth ?? AuthService.instance,
        _baseUrl = (baseUrl ?? AppLinks.firebaseDbUrl).replaceAll(RegExp(r'/+$'), '');

  static final CloudProfileService instance = CloudProfileService();

  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final AuthService _auth;
  final String _baseUrl;

  Future<Uri?> _uri(String uid) async {
    if (_baseUrl.isEmpty) return null;
    final token = await _auth.idToken();
    if (token == null) return null;
    return Uri.parse('$_baseUrl/users/$uid/profile.json').replace(queryParameters: {'auth': token});
  }

  /// The saved cloud profile, or null if there is none / it can't be reached.
  Future<Profile?> fetch() async {
    final user = _auth.user.value;
    if (user == null) return null;
    try {
      final uri = await _uri(user.uid);
      if (uri == null) return null;
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      return Profile(name: body['name']?.toString() ?? '', email: body['email']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Saves [profile]'s name and email to the cloud. Returns false on failure.
  Future<bool> push(Profile profile) async {
    final user = _auth.user.value;
    if (user == null) return false;
    try {
      final uri = await _uri(user.uid);
      if (uri == null) return false;
      final res = await _client
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': profile.name,
              'email': profile.email,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads the current local profile if signed in. Fire-and-forget.
  void pushIfSignedIn(Profile profile) {
    if (_auth.signedIn) unawaited(push(profile));
  }

  /// Run right after signing in: fills any EMPTY local profile field from the
  /// cloud copy (or, failing that, from the Google account), keeps anything
  /// the player already typed, then uploads the result.
  Future<void> syncAfterSignIn() async {
    final user = _auth.user.value;
    if (user == null) return;
    final local = await ProfileService.loadProfile();
    final cloud = await fetch();
    String pick(String a, String? b, String c) => a.isNotEmpty ? a : ((b ?? '').isNotEmpty ? b! : c);
    final merged = Profile(
      name: pick(local.name, cloud?.name, user.displayName),
      email: pick(local.email, cloud?.email, user.email),
      photoBase64: local.photoBase64,
    );
    if (merged.name != local.name || merged.email != local.email) {
      await ProfileService.saveProfile(merged);
    }
    await push(merged);
  }

  /// Signs in with Google and then syncs the profile. Returns the new user,
  /// or null if the player cancelled. Throws [AuthException] on failure
  /// (a failed profile sync never fails the sign-in).
  static Future<AuthUser?> signInAndSync() async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null) {
      try {
        await instance.syncAfterSignIn();
      } catch (_) {}
    }
    return user;
  }
}
