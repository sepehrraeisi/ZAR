# Device QA APK 20086 — Evidence

تاریخ: 2026-11-27 / 2026-11-28 00:32 +03:30
مرجع: conflict UX follow-ups after physical soak (PRs #84–#86)

## Build

- Commit: `3aab643` (master after merge of PR #86).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18086`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20086** (`--build-number` + project +2000 offset)
- APK SHA-256: `40F3F6DAC781BA457184093B13D2132AB86D99755DA92A083A6662E1FED5AC8C`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client change vs 20085

- Stale-revision Persian copy hints same-account multi-device/session (#84)
- `PaymentAllocationSheet` typed CAS conflict + **تازه‌سازی از سرور**;
  `stale_allocation_set` → `needsReload` (#85)
- Record-editor conflict reload widget coverage; epoch remote-refresh failure
  snackbar (was silent) (#86)

## Install

- Samsung `SM_N986U` / `R5CN70SG2BF`: `adb install -r` Success → versionCode
  **20086** at 2026-11-28 00:32 +03:30.
- moto e13 / `ZY22HS8MV4`: `adb install -r` Success → versionCode **20086** at
  2026-11-28 00:32 +03:30.

## Device smoke

1. Both devices: `am start` → home dashboard loads (گالری طلای مهر).
2. Shared open receive `USD ۲` / `SoakAirA214710` visible on both (SSE/epoch
   parity still healthy post-upgrade).
3. No crash on cold start after install.
