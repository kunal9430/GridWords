#!/usr/bin/env python3
"""Post-`flutter create` tweaks for the generated android/ folder.

Same changes codemagic.yaml makes, but written in Python so they run
identically on Linux (GitHub Actions) and macOS:
  1. force compileSdk 36 on every Gradle subproject (plugins like
     file_picker hardcode an older one and fail the AAR metadata check),
  2. set the launcher label to "Grid Words",
  3. set the real applicationId,
  4. allow INTERNET (online multiplayer).
"""
import pathlib, re

android = pathlib.Path("android")
MARKER = "GRID_WORDS_FORCE_COMPILESDK_36"

# 1. compileSdk 36 everywhere
kts, groovy = android / "settings.gradle.kts", android / "settings.gradle"
if kts.exists():
    path = kts
    addition = f"""
// {MARKER}
gradle.rootProject {{
    subprojects {{
        afterEvaluate {{
            val androidExt = extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {{
                androidExt.compileSdkVersion(36)
            }}
        }}
    }}
}}
"""
elif groovy.exists():
    path = groovy
    addition = f"""
// {MARKER}
gradle.rootProject {{
    subprojects {{ sub ->
        sub.afterEvaluate {{
            if (sub.hasProperty('android')) {{
                sub.android {{
                    compileSdkVersion 36
                }}
            }}
        }}
    }}
}}
"""
else:
    raise SystemExit("No android/settings.gradle(.kts) found")
text = path.read_text()
if MARKER not in text:
    path.write_text(text + addition)

# 2. app label
manifest = android / "app/src/main/AndroidManifest.xml"
text = re.sub(r'android:label="[^"]*"', 'android:label="Grid Words"', manifest.read_text())
# 2b. online play needs network access in release builds too
if "android.permission.INTERNET" not in text:
    text = text.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
manifest.write_text(text)

# 3. applicationId (namespace is deliberately left alone: it must match MainActivity's package)
for name in ("build.gradle", "build.gradle.kts"):
    f = android / "app" / name
    if f.exists():
        lines = [
            l.replace("com.example.grid_word_game", "com.kunalkumar.gridwords") if "applicationId" in l else l
            for l in f.read_text().split("\n")
        ]
        f.write_text("\n".join(lines))
print("android/ patched")
