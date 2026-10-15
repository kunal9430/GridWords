# Online play (different devices)

"Play Online" uses a Firebase **Realtime Database** through its plain REST API,
so there is no native Firebase/Gradle setup and no `google-services.json`.
Players sign in with **Google (Gmail)**; sign-in is optional for the rest of the
app and required only for Play Online and the cloud profile.

## One-time setup

### 1. Database
1. https://console.firebase.google.com > your project > **Build > Realtime Database**.
2. Paste the database URL into `lib/config/app_links.dart` (`firebaseDbUrl`, no trailing slash).

### 2. Google sign-in
1. **Build > Authentication > Get started > Sign-in method > Google > Enable.**
   (This is on the free Spark plan. Phone/OTP sign-in would need Blaze - not used.)
2. **Project settings > General > Your apps > Add app > Android.**
   Package name: `com.kunalkumar.gridwords`. Add the **SHA-1** of the key that
   signs your APK (see below), then save.
3. Copy two values into `lib/config/app_links.dart`:
   * `firebaseApiKey` - Project settings > General > **Web API Key**.
   * `googleServerClientId` - Authentication > Sign-in method > Google >
     Web SDK configuration > **Web client ID**
     (`...apps.googleusercontent.com`).
4. Rebuild the app.

#### The SHA-1 must match the signing key
Google refuses sign-in (error code 10 / "DEVELOPER_ERROR") if the APK's signing
key is not registered. The GitHub workflow signs with your release keystore when
the `KEYSTORE_*` secrets exist; otherwise it uses a throw-away debug key that
changes every run, which can **never** work with Google sign-in. So:

* Make sure the keystore secrets are set, then get its SHA-1:
  `keytool -list -v -keystore release.keystore -alias <KEY_ALIAS>`
* Add that SHA-1 under the Android app in Firebase project settings.
* If you later publish on Google Play with Play App Signing, also add the
  **App signing key SHA-1** shown in Play Console > Setup > App signing.

### 3. Rules
Publish these in **Realtime Database > Rules** (publish them only after the new
build is out - app versions without sign-in are refused by these rules):

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "rooms": {
      "$code": {
        ".read": "auth != null",
        "lobby": {
          ".write": "auth != null && (!data.exists() || data.child('started').val() !== true || data.child('members').hasChild(auth.uid))"
        },
        "game": {
          ".write": "auth != null && root.child('rooms').child($code).child('lobby').child('members').hasChild(auth.uid)"
        }
      }
    }
  }
}
```

* Only signed-in players can read a room.
* Before a game starts anyone with the code can take a free seat; once it has
  started only the room's own members can change the lobby, and only members
  can write to the board.
* Each player can read and write only their own `users/<uid>/profile`.

## How it works

* **Sign-in:** the `google_sign_in` plugin returns a Google ID token, which is
  exchanged at Firebase (`accounts:signInWithIdp`) for a Firebase login. The
  Firebase ID token is sent as `?auth=` on every database request and refreshed
  automatically. The login is remembered on the device until the player signs out.
* **Rooms:** the host taps **Create Room** (name, 2-3 players, board size) and
  shares the code. Friends tap **Join Room**. The host taps **Start Game**.
* **Seats and re-joining:** the lobby records `members: {<user id>: <seat>}`.
  Joining with a code first checks that list: someone who was already a member
  gets their original seat back - before or after the game starts, even if the
  room is full - and a stranger is refused once the game has started or the
  room is full. Leaving never costs a player their seat.
* **Your screen:** only your own score card (30% of the width) is shown beside a
  live leaderboard of everyone's score (70%). Placing a letter, scoring (+/-),
  the number strip and clearing cells work only on your turn; the turn passes
  when you record your score.
* **Board sync:** every device polls every 1.5 s and uploads its own changes.
  Writes use ETag / `If-Match`, so if two writes collide the later one is
  rejected and that device adopts the newer board.
* **Cloud profile:** after signing in, your name and email are saved at
  `users/<uid>/profile` and restored on a new phone. The profile photo stays on
  the device.
* Online matches have no computer player and are not auto-saved to Saved Games.
