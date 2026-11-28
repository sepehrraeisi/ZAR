# Device QA APK 20089 — Evidence

تاریخ: 2026-11-28 18:24 +03:30  
مرجع: device attribution Option B (PR #93) + signup UI gate (PR #77) on
production after `SIGNUP-REOPEN-DEPLOY-EVIDENCE-2026-11-28.md`.

## Build

- Commit: `c22b832` (master after merge of PR #93).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18089`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20089** (`--build-number` + project +2000 offset)
- APK SHA-256: `878EAEC84F1B6DEF0B03FD375E0391A2FDE636CED70529853DDD2708BB86C5C9`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client change vs 20088

- `ZarDeviceAttributionStore` Keystore installation id + opaque hash export
- Domain stamps `createdFromDevice` / `updatedFromDevice` on bridge/cashbox
- Signup `onSignUp` restored in `ZarAuthGate` (server already open)

## Install

- moto e13 / `ZY22HS8MV4`: `adb install -r` Success → versionCode **20089** at
  2026-11-28 18:24 +03:30.
- Samsung `SM_N986U` / `R5CN70SG2BF`: **not attached** this session — install
  pending when USB returns.

## Device smoke

1. moto: `am start` → `MainActivity` visible, pid present, no immediate crash.
2. Attribution stamp + dual-device conflict QA: deferred until Samsung reattach.
