# Device QA APK 20084 — Evidence

تاریخ: 2026-11-25
مرجع: RELEASE-RUNBOOK + ZAR-MOB-001 backup deny + release HTTPS/timeout

## Build

- Commit: `eb065c3` (master after PR #67).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18084`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20084** (`--build-number` + project +2000 offset)
- APK SHA-256: `6464fa70b77cc722c5a4e341fb93835d83326d2910282b5c6c8713dbbc0cd909`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client capabilities added since 20083

- Android `allowBackup=false` + backup / data-extraction XML excludes
  (`ANDROID-BACKUP-DENY-EVIDENCE-2026-11-25.md`)
- Release HTTPS baseUrl gate (`kReleaseMode`) + 30s REST timeout
  (`RELEASE-HTTPS-CLIENT-TIMEOUT-EVIDENCE-2026-11-25.md`)
- Android cleartext denied (main network security config)

## Install

- Target: owner Samsung (`SM_N986U` / `R5CN70SG2BF`), previously versionCode
  **20083**.
- `adb install -r` → **Success** at 2026-11-25 15:47 +03:30.
- Installed: versionCode **20084**, versionName `1.0.0`,
  `lastUpdateTime=2026-11-25 15:47:39`.

## Remaining

- Physical multi-device soak (`MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`) still
  needs a second session/device before advertising cloud reliability.
