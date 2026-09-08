# ZAR+ Android release candidate

## Verified application configuration

- Package / application ID: `com.zarplus.app`
- Version name: `1.0.0`
- Version code: `1`
- Minimum SDK: 24
- Target SDK: 36
- Compile SDK: 36
- Java/Kotlin target: 17
- Firebase runtime: disabled
- Production data source: local Drift/SQLite repository

Version name and code come from `pubspec.yaml` (`1.0.0+1`). Increase the build
number before publishing a replacement artifact to a store or test track.

## Release signing

Release builds never use Flutter's debug signing key. Copy
`android/key.properties.example` to the ignored `android/key.properties` and
point `storeFile` to a securely backed-up keystore outside the repository. A
release build fails with a clear error when these values are absent.

Never commit the keystore, `key.properties`, passwords, aliases intended to be
private, `local.properties`, or signing output. Losing a production signing key
prevents publishing upgrades under the same Android application identity.

## Reproducible build

Install Android SDK platform 36, build-tools 36, NDK `28.2.13676358`, and JDK
17. Keep the SDK location in ignored `android/local.properties`. The repository
tracks the Gradle wrapper scripts, wrapper JAR, and wrapper properties.

The current Flutter toolchain requires Gradle 8.14 and Kotlin 2.2.20 for this
project. Flutter already warns that a later release will require Gradle 9.1,
Android Gradle Plugin 9.0.1, and Kotlin 2.3.20. Upgrade those together in a
separate, validated build-tool migration rather than during RC packaging.

From the repository root:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build apk --split-per-abi --release
```

## Branding status

The checked-in Android launcher images are Flutter placeholder icons, not an
approved ZAR+ master logo. No approved high-resolution logo source, adaptive
foreground/background pair, or splash artwork exists in the repository. They
have deliberately not been replaced or synthesized in this release batch.

Before public distribution, provide these approved source assets:

- square master logo, preferably SVG or transparent PNG at least 1024×1024;
- adaptive icon foreground with Android safe-zone padding;
- adaptive icon background color or artwork;
- monochrome notification icon;
- splash mark suitable for light and dark backgrounds.

The existing `launch_background.xml` files already provide the standard native
splash structure and currently show a neutral background only.

## Real-device release checklist

- Install the release APK and verify cold startup without Firebase.
- Create a person, deal and settlement; force-stop and reopen; verify all data.
- Archive and restore a person after restart.
- Schedule a reminder, choose a custom time, snooze it, and verify delivery.
- Reboot the device and verify eligible reminders are reconstructed.
- Export JSON V2, preview it, confirm replacement restore, and verify records.
- Verify Persian RTL, Jalali dates and LTR currency/amount rendering.
- Exercise background/foreground, process termination and supported rotation.
- Confirm notification permission behavior on Android 13 and later.
- Record device model, Android version, APK ABI and observed failures.
