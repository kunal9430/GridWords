#!/usr/bin/env python3
"""Wires release signing into the android/ project that `flutter create` generates.

`flutter create` makes the release build type sign with the DEBUG key, which is
a different throw-away key on every CI run (so one build can't be installed over
another) and is rejected by Google Play. This script:
  * makes android/app/build.gradle(.kts) read android/key.properties, and
  * points the `release` build type at a `release` signing config built from it.
Run it after `flutter create` and after writing android/key.properties.
Uses fully-qualified class names (no `import`) so it is valid wherever it lands
in a Gradle Kotlin script.
"""
import pathlib
import re

app = pathlib.Path("android/app")
kts, groovy = app / "build.gradle.kts", app / "build.gradle"

if kts.exists():
    path = kts
    text = path.read_text()
    if "keystoreProperties" not in text:
        prelude = (
            "val keystoreProperties = java.util.Properties()\n"
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        # right after the closing brace of the plugins { } block
        text, n = re.subn(r"(plugins\s*\{.*?\n\}\s*\n)", lambda m: m.group(1) + "\n" + prelude, text, count=1, flags=re.S)
        if n != 1:
            raise SystemExit("Could not find the plugins { } block in build.gradle.kts")
    if "signingConfigs {" not in text:
        block = (
            "    signingConfigs {\n"
            '        create("release") {\n'
            '            keyAlias = keystoreProperties["keyAlias"] as String?\n'
            '            keyPassword = keystoreProperties["keyPassword"] as String?\n'
            '            storeFile = keystoreProperties["storeFile"]?.let { file(it) }\n'
            '            storePassword = keystoreProperties["storePassword"] as String?\n'
            "        }\n"
            "    }\n\n"
        )
        text, n = re.subn(r"(\bbuildTypes\s*\{)", lambda m: block.lstrip() + "    " + m.group(1), text, count=1)
        if n != 1:
            raise SystemExit("Could not find buildTypes { } in build.gradle.kts")
    text = text.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
    path.write_text(text)
elif groovy.exists():
    path = groovy
    text = path.read_text()
    if "keystoreProperties" not in text:
        prelude = (
            "def keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        text, n = re.subn(r"(\bandroid\s*\{)", lambda m: prelude + m.group(1), text, count=1)
        if n != 1:
            raise SystemExit("Could not find android { } in build.gradle")
    if "signingConfigs {" not in text:
        block = (
            "    signingConfigs {\n"
            "        release {\n"
            "            keyAlias keystoreProperties['keyAlias']\n"
            "            keyPassword keystoreProperties['keyPassword']\n"
            "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
            "            storePassword keystoreProperties['storePassword']\n"
            "        }\n"
            "    }\n\n"
        )
        text, n = re.subn(r"(\bbuildTypes\s*\{)", lambda m: block.lstrip() + "    " + m.group(1), text, count=1)
        if n != 1:
            raise SystemExit("Could not find buildTypes { } in build.gradle")
    text = re.sub(r"signingConfig\s+signingConfigs\.debug", "signingConfig signingConfigs.release", text)
    path.write_text(text)
else:
    raise SystemExit("No android/app/build.gradle(.kts) found")
print("release signing wired into", path)
