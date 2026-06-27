# Building the Android APK

The project is already configured for Android (`export_presets.cfg` → preset
**"Android"**: package `com.gods.game`, name "Gods", landscape, immersive,
armeabi-v7a + arm64-v8a, output `builds/android/gods.apk`). You only need an
Android toolchain to compile it. Two ways:

## A. Automatic — GitHub Actions (no local setup)
1. Push the repo (the workflow `.github/workflows/android.yml` is included).
2. On GitHub → **Actions** tab → **Build Android APK** → **Run workflow**.
3. When it finishes, open the run → **Artifacts** → download `gods-debug-apk`.
4. Copy `gods.apk` to your phone and install it (enable "install unknown apps").

This builds a **debug** APK — perfect for sideloading onto your own phones.

## B. Local — Godot editor (recommended for iterating)
Prerequisites (one-time):
- **JDK 17** (Temurin/OpenJDK).
- **Android SDK** with **platform-tools** + **build-tools;34.0.0** (install via
  Android Studio, or `cmdline-tools` + `sdkmanager`).
- **Godot 4.3** editor.
- **Android export templates 4.3**: Editor → *Manage Export Templates* → Download.

Configure once in Godot: *Editor → Editor Settings → Export → Android* →
- **Android SDK Path** = your SDK folder (the one with `platform-tools/`).
- **Debug Keystore**: click to let Godot generate a debug keystore (or it
  auto-creates `~/.android/debug.keystore`).

Then either:
- **GUI**: *Project → Export → Android → Export Project* (uncheck "Export With
  Debug" only if you have a release keystore). Saves `builds/android/gods.apk`.
- **CLI** (headless):
  ```
  godot --headless --export-debug "Android" builds/android/gods.apk
  ```

## Debug vs Release
- **Debug APK** (the above): signed with the debug keystore. Installs on any
  phone via sideload — fine for the two private players. Cannot be uploaded to
  the Play Store.
- **Release APK/AAB** (for publishing): create your own keystore once —
  ```
  keytool -keyalg RSA -genkeypair -alias gods -keystore gods-release.keystore \
    -storepass <pass> -keypass <pass> -dname "CN=Gods" -validity 10000
  ```
  Set it as the **Release** keystore in Editor Settings → Export → Android (or
  the env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`), then
  `godot --headless --export-release "Android" builds/android/gods.apk`.
  For the Play Store, set `gradle_build/export_format=1` (AAB) and enable
  `gradle_build/use_gradle_build` for a custom build. Keep the keystore secret
  and backed up — you need the SAME one for every future update.

## Notes
- App id is `com.gods.game`, name "Gods", landscape — change in
  `export_presets.cfg` (`package/unique_name`, `package/name`) before publishing.
- The Web build (`builds/web/`) already covers iOS for free via Safari.
