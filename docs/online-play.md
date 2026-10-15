# Online play (different devices)

"Play Online" uses a Firebase **Realtime Database** through its plain REST API,
so there is no native Firebase/Gradle setup and no `google-services.json`.

## One-time setup

1. Go to https://console.firebase.google.com and create a project (free Spark plan is plenty).
2. **Build > Realtime Database > Create database** (pick any region).
3. Open the **Rules** tab and paste the rules below, then **Publish**.
4. Copy the database URL shown at the top of the **Data** tab, e.g.
   `https://grid-words-12345-default-rtdb.firebaseio.com`
5. Paste it (no trailing slash) into `lib/config/app_links.dart`:
   `static const String firebaseDbUrl = '...';`
6. Rebuild the app.

## Rules

Rooms are addressed by a random 6-character code and need no sign-in:

```json
{
  "rules": {
    "rooms": {
      "$code": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

Anyone who knows (or guesses) a code can read and edit that room, and
rooms are not deleted automatically. That is fine for a casual game, but
if you want to tighten it later, add Firebase Anonymous Auth and an
expiry/clean-up job.

## How it works

* Host taps **Create Room** (name, 2-3 players, board size) and shares the code.
* Friends tap **Join Room**, enter the code and their name.
* The host taps **Start Game**; every device opens the same board.
* The board is shared: anyone may place a letter, score or switch turns.
  Each device polls every 1.5 s and uploads its own changes. Writes use
  ETag / `If-Match`, so if two people act at the same instant the later
  one is rejected and that device simply adopts the newer board.
* Online matches have no computer player and are not auto-saved to the
  Saved Games list.
