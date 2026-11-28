# Device QA APK 20088 — Evidence

تاریخ: 2026-11-28 17:17 +03:30
مرجع: cashbox CAS conflict UX (PR #90) on top of APK 20087

## Build

- Commit: `b75d186` (master after merge of PR #90).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18088`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20088** (`--build-number` + project +2000 offset)
- APK SHA-256: `CA810D1FA2A5AA33B0DF815236C5E7BE4B64E11E39EF6ABFA8FF26B062B2FF3F`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client change vs 20087

- Cashbox entry sheet typed CAS conflict + **تازه‌سازی از سرور**
  (`CASHBOX-CAS-CONFLICT-UX-EVIDENCE-2026-11-28.md`)
- FINDINGS next-order hygiene (docs only)

## Install

- Samsung `SM_N986U` / `R5CN70SG2BF`: `adb install -r` Success → versionCode
  **20088** at 2026-11-28 17:17 +03:30.
- moto e13 / `ZY22HS8MV4`: `adb install -r` Success → versionCode **20088** at
  2026-11-28 17:17 +03:30.

## Device smoke

1. Both devices: `am start` → home loads without crash.
