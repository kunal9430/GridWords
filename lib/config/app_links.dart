/// Central place for the app's download link (used by the "Share with
/// friends" and "Share result" buttons).
///
/// IMPORTANT: `downloadUrl` below is a PLACEHOLDER. Once your app's page is
/// live on Uptodown, replace the value below with the exact page URL, e.g.
/// `https://gridwords.en.uptodown.com/android`.
class AppLinks {
  static const String downloadUrl =
      'https://www.mediafire.com/folder/cja04q2zwpgns/Grid+Game'; // TODO: replace with your real Uptodown URL

  /// Kept for backwards compatibility with any old references.
  static const String playStoreUrl = downloadUrl;

  /// Shown in the profile menu's Help item.
  static const String supportEmail = 'gridgamesplay1@gmail.com';

  /// Base URL of your Firebase Realtime Database, used for "Play Online".
  /// Create a free project at https://console.firebase.google.com, add a
  /// Realtime Database, and paste its URL here WITHOUT a trailing slash, e.g.
  /// `https://grid-words-12345-default-rtdb.firebaseio.com`.
  /// Leave empty to hide online play's connection (the screen will explain).
  static const String firebaseDbUrl =
      'https://grid-words-e564c-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Firebase "Web API key" (Project settings > General). Used to turn a
  /// Google sign-in into a Firebase login over plain REST. It is a public
  /// identifier, not a secret. Leave empty to disable Google sign-in.
  static const String firebaseApiKey = '';

  /// The OAuth **Web client ID** of the same Google Cloud / Firebase project,
  /// e.g. `1234567890-abcdefg.apps.googleusercontent.com` (Firebase console >
  /// Authentication > Sign-in method > Google > Web SDK configuration).
  /// Google sign-in on Android needs it to hand back an ID token.
  static const String googleServerClientId = '';
}
