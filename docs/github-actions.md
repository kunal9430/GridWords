# Building with GitHub Actions (replaces Codemagic)

Workflows live in `.github/workflows/`:

| File | When it runs | Output |
|---|---|---|
| `build-apk.yml` | every push to main/master, pull requests, tags `v*`, manual | `GridWords-APK` (file `GridWords.apk`) artifact (+ GitHub Release on tags) |
| `build-aab.yml` | tags `v*`, manual | `grid-words-aab` artifact (Play Store bundle) |

Both regenerate the Android project (`flutter create --platforms=android .`), then run
`tools/patch_android.py` (compileSdk 36, app name "Grid Words", applicationId
`com.kunalkumar.gridwords`) and, when signing secrets exist, `tools/sign_android.py`.

## One-time setup
1. Create a GitHub repository and push this folder (`.gitignore` already excludes `android/`, `build/`, keystores).
2. **Signing key (strongly recommended).** Reuse the keystore you used in Codemagic if you have it - Google Play
   needs the same upload key. Otherwise create one and BACK IT UP (losing it means you can never update the app):
   ```
   keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   base64 -w0 release.jks        # macOS: base64 -i release.jks
   ```
3. Repository -> Settings -> Secrets and variables -> Actions -> New repository secret:
   `KEYSTORE_BASE64` (the base64 text), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
   (the same values you used for CM_KEYSTORE / CM_KEYSTORE_PASSWORD / CM_KEY_ALIAS / CM_KEY_PASSWORD).
   Without them the APK still builds but is signed with a throw-away debug key, so a new build
   cannot be installed over the old one, and the AAB workflow refuses to run.

## Using it
* Push to `main` -> Actions tab -> run -> download **GridWords-APK** from the run's Artifacts.
* Release: `git tag v1.0.1 && git push origin v1.0.1` -> builds the APK (attached to a GitHub Release)
  and the AAB. The build number is the workflow run number, so it always increases.
* Version name comes from `version:` in `pubspec.yaml` (currently `1.0.0+1`; the `+N` part is overridden by the run number).
* The `test` job runs `flutter analyze` and `flutter test` but does not block the APK. To make it a gate, remove
  `continue-on-error: true` from it and add `needs: test` to the `apk` job.

## Uploading through the GitHub website (drag and drop)

- Drag-and-drop **skips folders that start with a dot**, so `.github/` and `.gitignore` are not uploaded.
  Create the workflow once in the browser: **Add file → Create new file**, type
  `.github/workflows/build-apk.yml`, paste the file contents, commit.
- Drag-and-drop never deletes: remove old files (e.g. `codemagic.yaml`) from the website by opening
  the file → ⋯ → **Delete file**.
- The workflow runs on a push to **any branch**. Open **Actions → Build Android APK → latest run →
  Artifacts → GridWords-APK**, download the zip and unzip it to get `GridWords.apk`.
