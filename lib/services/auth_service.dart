import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_links.dart';

/// Thrown when signing in (or refreshing a login) fails.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// The signed-in player. [uid] is the permanent Firebase user id: it is the
/// same on every device and every reinstall, which is what lets a player
/// re-join an online match they were already part of.
class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;

  const AuthUser({required this.uid, this.email = '', this.displayName = '', this.photoUrl = ''});

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl);
}

/// Google (Gmail) sign-in backed by Firebase Authentication, done through the
/// plain REST API like the rest of the app's Firebase use (no native Firebase
/// setup, no google-services.json):
///
///   1. the `google_sign_in` plugin shows the account picker and returns a
///      Google ID token;
///   2. that token is exchanged at Identity Toolkit (`accounts:signInWithIdp`)
///      for a Firebase user + ID token + refresh token;
///   3. the Firebase ID token is sent as `?auth=` on every Realtime Database
///      request, so the database rules can tell who is calling.
///
/// Signing in is optional - it is only needed for Play Online and the cloud
/// profile.
class AuthService {
  AuthService({
    http.Client? client,
    String? apiKey,
    String? serverClientId,
    Future<String?> Function()? googleIdToken,
    Future<void> Function()? googleSignOut,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppLinks.firebaseApiKey,
        _serverClientId = serverClientId ?? AppLinks.googleServerClientId,
        _googleIdTokenOverride = googleIdToken,
        _googleSignOutOverride = googleSignOut;

  /// The app-wide instance.
  static final AuthService instance = AuthService();

  static const String _uidKey = 'auth_uid';
  static const String _emailKey = 'auth_email';
  static const String _nameKey = 'auth_name';
  static const String _photoKey = 'auth_photo';
  static const String _refreshKey = 'auth_refresh_token';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _apiKey;
  final String _serverClientId;
  final Future<String?> Function()? _googleIdTokenOverride;
  final Future<void> Function()? _googleSignOutOverride;
  GoogleSignIn? _google;

  /// The signed-in player, or null when signed out. Listen to this to keep
  /// the UI in step.
  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);

  String? _idToken;
  DateTime? _idTokenExpiry;
  String? _refreshToken;
  Future<String?>? _refreshing;

  bool get configured => _apiKey.isNotEmpty && _serverClientId.isNotEmpty;
  bool get signedIn => user.value != null;

  /// Restores a previous login from disk. Call once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_uidKey);
    final refresh = prefs.getString(_refreshKey);
    if (uid == null || uid.isEmpty || refresh == null || refresh.isEmpty) return;
    _refreshToken = refresh;
    user.value = AuthUser(
      uid: uid,
      email: prefs.getString(_emailKey) ?? '',
      displayName: prefs.getString(_nameKey) ?? '',
      photoUrl: prefs.getString(_photoKey) ?? '',
    );
  }

  /// Shows Google's account picker and signs in. Returns null if the player
  /// closed the picker without choosing an account.
  Future<AuthUser?> signInWithGoogle() async {
    if (!configured) {
      throw const AuthException(
        'Google sign-in is not set up in this build yet (see docs/online-play.md).',
      );
    }
    final String? googleToken;
    try {
      googleToken = await (_googleIdTokenOverride ?? _defaultGoogleIdToken)();
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException("Google sign-in didn't complete. Check your internet and try again.");
    }
    if (googleToken == null) return null; // cancelled

    final res = await _post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:signInWithIdp', {'key': _apiKey}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'postBody': 'id_token=$googleToken&providerId=google.com',
        'requestUri': 'http://localhost',
        'returnIdpCredential': true,
        'returnSecureToken': true,
      }),
    );
    final json = _decode(res);
    if (res.statusCode != 200) {
      throw AuthException(_describeError(json, "Couldn't sign in with Google. Please try again."));
    }
    final uid = json['localId']?.toString() ?? '';
    final idToken = json['idToken']?.toString();
    final refresh = json['refreshToken']?.toString();
    if (uid.isEmpty || idToken == null || refresh == null) {
      throw const AuthException("Couldn't sign in with Google. Please try again.");
    }
    final signedInUser = AuthUser(
      uid: uid,
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['fullName']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString() ?? '',
    );
    _refreshToken = refresh;
    _idToken = idToken;
    _idTokenExpiry = _expiryFrom(json['expiresIn']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, signedInUser.uid);
    await prefs.setString(_emailKey, signedInUser.email);
    await prefs.setString(_nameKey, signedInUser.displayName);
    await prefs.setString(_photoKey, signedInUser.photoUrl);
    await prefs.setString(_refreshKey, refresh);
    user.value = signedInUser;
    return signedInUser;
  }

  /// A valid Firebase ID token for the signed-in player (refreshed when it is
  /// about to expire), or null when signed out.
  Future<String?> idToken() async {
    if (user.value == null) return null;
    final expiry = _idTokenExpiry;
    if (_idToken != null && expiry != null && DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 2)))) {
      return _idToken;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refresh = _refreshToken;
    if (refresh == null || !configured) {
      await signOut();
      return null;
    }
    final res = await _post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': _apiKey}),
      headers: const {},
      body: {'grant_type': 'refresh_token', 'refresh_token': refresh},
    );
    final json = _decode(res);
    if (res.statusCode == 200) {
      final token = json['id_token']?.toString();
      if (token != null && token.isNotEmpty) {
        _idToken = token;
        _idTokenExpiry = _expiryFrom(json['expires_in']);
        final newRefresh = json['refresh_token']?.toString();
        if (newRefresh != null && newRefresh.isNotEmpty && newRefresh != _refreshToken) {
          _refreshToken = newRefresh;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_refreshKey, newRefresh);
        }
        return token;
      }
    }
    // The login was revoked or the account removed: sign out for real.
    // Anything else (server hiccup) is reported but keeps the login.
    final message = _describeError(json, '');
    if (res.statusCode == 400 &&
        (message.contains('TOKEN_EXPIRED') ||
            message.contains('INVALID_REFRESH_TOKEN') ||
            message.contains('USER_DISABLED') ||
            message.contains('USER_NOT_FOUND'))) {
      await signOut();
      throw const AuthException('Your sign-in expired. Please sign in with Google again.');
    }
    throw const AuthException("Couldn't refresh your sign-in. Check your internet and try again.");
  }

  Future<void> signOut() async {
    try {
      await (_googleSignOutOverride ?? _defaultGoogleSignOut)();
    } catch (_) {
      // Nothing to undo on Google's side if it was never opened.
    }
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_uidKey, _emailKey, _nameKey, _photoKey, _refreshKey]) {
      await prefs.remove(k);
    }
    _idToken = null;
    _idTokenExpiry = null;
    _refreshToken = null;
    user.value = null;
  }

  // ----------------------------------------------------------------------

  Future<String?> _defaultGoogleIdToken() async {
    final google = _google ??= GoogleSignIn(scopes: const ['email'], serverClientId: _serverClientId);
    // Always show the account picker, so a player can switch Google accounts.
    try {
      await google.signOut();
    } catch (_) {}
    final account = await google.signIn();
    if (account == null) return null;
    final token = (await account.authentication).idToken;
    if (token == null || token.isEmpty) {
      throw const AuthException(
        "Google didn't return a sign-in token. The app's Google sign-in setup may be incomplete.",
      );
    }
    return token;
  }

  Future<void> _defaultGoogleSignOut() async {
    await _google?.signOut();
  }

  Future<http.Response> _post(Uri uri, {required Map<String, String> headers, required Object body}) async {
    try {
      return await _client.post(uri, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException {
      throw const AuthException('The connection timed out. Check your internet and try again.');
    } catch (_) {
      throw const AuthException("Couldn't reach the server. Check your internet and try again.");
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final v = jsonDecode(res.body);
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _describeError(Map<String, dynamic> json, String fallback) {
    final err = json['error'];
    if (err is Map && err['message'] != null) {
      final m = err['message'].toString();
      if (m.contains('OPERATION_NOT_ALLOWED')) {
        return 'Google sign-in is switched off for this project. Enable it in Firebase > Authentication.';
      }
      if (m.contains('INVALID_IDP_RESPONSE') || m.contains('INVALID_CERT_HASH')) {
        return "Google sign-in was rejected. The app's signing key (SHA-1) or client ID is not registered in Firebase.";
      }
      return fallback.isEmpty ? m : fallback;
    }
    return fallback;
  }

  DateTime _expiryFrom(Object? seconds) {
    final s = int.tryParse(seconds?.toString() ?? '') ?? 3600;
    return DateTime.now().add(Duration(seconds: s));
  }
}
