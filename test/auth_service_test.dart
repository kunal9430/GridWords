import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_word_game/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AuthService make(MockClient c, {Future<String?> Function()? google}) => AuthService(
        client: c,
        apiKey: 'KEY',
        serverClientId: 'web-client',
        googleIdToken: google ?? () async => 'google-id-token',
        googleSignOut: () async {},
      );

  test('Google sign-in is exchanged for a Firebase user and remembered', () async {
    late http.Request seen;
    final auth = make(MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode({
          'localId': 'uid1',
          'idToken': 'fb-id',
          'refreshToken': 'fb-refresh',
          'expiresIn': '3600',
          'email': 'a@gmail.com',
          'displayName': 'Ann',
        }),
        200,
      );
    }));
    final user = await auth.signInWithGoogle();
    expect(user!.uid, 'uid1');
    expect(user.email, 'a@gmail.com');
    expect(auth.signedIn, isTrue);
    expect(seen.url.host, 'identitytoolkit.googleapis.com');
    expect(seen.url.queryParameters['key'], 'KEY');
    expect(jsonDecode(seen.body)['postBody'], contains('id_token=google-id-token'));
    expect(await auth.idToken(), 'fb-id'); // still valid: no refresh call

    // A fresh app start restores the same login from disk.
    final again = make(MockClient((_) async => http.Response('{}', 500)));
    await again.init();
    expect(again.user.value!.uid, 'uid1');
  });

  test('cancelling the Google picker signs nobody in', () async {
    final auth = make(MockClient((_) async => http.Response('{}', 500)), google: () async => null);
    expect(await auth.signInWithGoogle(), isNull);
    expect(auth.signedIn, isFalse);
  });

  test('an expired token is refreshed; a revoked login signs out', () async {
    var refreshCalls = 0;
    var revoked = false;
    final auth = make(MockClient((req) async {
      if (req.url.host == 'identitytoolkit.googleapis.com') {
        return http.Response(
          jsonEncode({'localId': 'uid1', 'idToken': 'old', 'refreshToken': 'r1', 'expiresIn': '1'}),
          200,
        );
      }
      refreshCalls++;
      if (revoked) return http.Response(jsonEncode({'error': {'message': 'TOKEN_EXPIRED'}}), 400);
      return http.Response(jsonEncode({'id_token': 'new', 'refresh_token': 'r2', 'expires_in': '3600'}), 200);
    }));
    await auth.signInWithGoogle();
    expect(await auth.idToken(), 'new'); // 1 s lifetime is already "about to expire"
    expect(refreshCalls, 1);

    revoked = true;
    // Force another refresh by signing in again with a short-lived token.
    await auth.signInWithGoogle();
    await expectLater(auth.idToken(), throwsA(isA<AuthException>()));
    expect(auth.signedIn, isFalse);
  });

  test('sign-out forgets the login', () async {
    final auth = make(MockClient((_) async => http.Response(
          jsonEncode({'localId': 'u', 'idToken': 't', 'refreshToken': 'r', 'expiresIn': '3600'}),
          200,
        )));
    await auth.signInWithGoogle();
    await auth.signOut();
    expect(auth.signedIn, isFalse);
    expect(await auth.idToken(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_uid'), isNull);
  });
}
