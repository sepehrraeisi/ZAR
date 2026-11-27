# Device QA APK 20087 — Evidence

تاریخ: 2026-11-28 00:52 +03:30
مرجع: catalog CAS conflict UX (PR #88) on top of APK 20086 conflict stack

## Build

- Commit: `4d564ee` (master after merge of PR #88).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18087`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20087** (`--build-number` + project +2000 offset)
- APK SHA-256: `958D2EDA1A3FE1ED6C17DB68F69B8DA1FA5719956375D9A21B56B2150E062E5C`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client change vs 20086

- Coin/currency catalog save/archive/restore through write coordinator;
  typed conflict SnackBar + **تازه‌سازی** (`CATALOG-CAS-CONFLICT-UX-EVIDENCE-2026-11-27.md`)

## Install

- Samsung `SM_N986U` / `R5CN70SG2BF`: `adb install -r` Success → versionCode
  **20087** at 2026-11-28 00:52 +03:30.
- moto e13 / `ZY22HS8MV4`: `adb install -r` Success → versionCode **20087** at
  2026-11-28 00:52 +03:30.

## Device smoke

1. Both devices: `am start` → home loads without crash.
