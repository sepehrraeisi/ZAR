# Device QA APK 20085 — Evidence

تاریخ: 2026-11-27
مرجع: PR #81 settlement detail note refresh + dual-USB physical soak continuation

## Build

- Commit: `2781f8a` (master after merge of PR #81 / `a8eecdd`).
- Command:
  `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=18085`
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Package: `com.zarplus.app`
- versionName: `1.0.0`
- versionCode: **20085** (`--build-number` + project +2000 offset)
- APK SHA-256: `D6F15CC6FFC8B1F8A0DFBA8BE9F47F03BC87569229DFFC7D9D44EC4815C27AFB`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches RELEASE-SIGNING-EVIDENCE)

## Client change vs 20084

- After `ConfirmedRecordEditorSheet` saves a settlement, `_openRecord` adopts
  the returned `AppRecord` into a `StatefulBuilder` so یادداشت updates in the
  still-open action sheet without dismiss/reopen
  (`SETTLEMENT-DETAIL-NOTE-REFRESH-EVIDENCE-2026-11-25.md`).

## Install

- Samsung `SM_N986U` / `R5CN70SG2BF`: `adb install -r` Success → versionCode
  **20085** at 2026-11-27 23:00:02 +03:30.
- moto e13 / `ZY22HS8MV4`: `adb install -r` Success → versionCode **20085** at
  2026-11-27 23:00:12 +03:30.

## Device verify (note refresh)

1. Samsung: create open receive 2 USD for `SoakAirA214710`; edit note →
   `refresh20085`; save.
2. Still-open settlement sheet shows یادداشت `refresh20085` immediately
   (**Pass** — no dismiss/reopen).
3. moto e13: SSE/epoch shows same open settlement; detail shows
   `refresh20085` (**Pass** sync).
4. moto e13: edit note → type `refreshB20085` (adb `KEYCODE_DEL` did not fully
   clear prior text, so UI showed a concatenated value); still-open sheet
   updated immediately without dismiss/reopen (**Pass** in-sheet refresh on
   second device — adb clear flake only).

## Related soak (same dual-USB session, logged under `.tmp-soak/`)

Airplane catch-up, terminal peer complete, cancel peer — Pass on 20084 before
upgrade; note-refresh gate closed on 20085.
