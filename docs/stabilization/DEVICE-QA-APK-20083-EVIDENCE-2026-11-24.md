# Device QA APK 20083 — Evidence

تاریخ: 2026-11-24
مرجع: RELEASE-RUNBOOK + ZAR-DATA-002 (epoch/SSE + actor stamp on next APK)

## Build

- Commit: `db57bf1` (master at build time; includes epoch watch, SSE client,
  Caddy flush already in prod).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18083`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20083** (`--build-number` + project +2000 offset)
- APK SHA-256: `117e117adc0ca86d394f9c428084e83a281d23b1ba08c86202692e6a84bdd337`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client capabilities in this APK

- Create-time actor stamp (PocketBase uid; transitional `local-user` still
  accepted server-side)
- Conflict reload snackbar + editor **تازه‌سازی**
- Workspace epoch poll (15s) + resume check
- PocketBase SSE subscribe on `zar_workspaces/{id}` with poll fallback

## Install

- Target: owner Samsung (`SM_N986U`) previously on versionCode **18082**.
- `adb install -r` status: **pending reconnect** at evidence write time
  (device dropped from `adb devices` after build). Re-run:
  `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- After install: confirm `dumpsys package` shows versionCode **20083**, then
  follow `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`.
