# Android backup / data-extraction deny (ZAR-MOB-001 slice)

تاریخ: 2026-11-25 — شاخه: `feature/android-backup-deny-zar-mob-001`

## Goal

Keep local financial DB + prefs out of Auto Backup and device-to-device
transfer until local DB encryption and an owner recovery policy exist.
Token storage already uses Keystore-backed `ZarSecureTokenStore`.

## Change

- `android/app/src/main/AndroidManifest.xml`:
  - `android:allowBackup="false"`
  - `android:fullBackupContent="@xml/backup_rules"`
  - `android:dataExtractionRules="@xml/data_extraction_rules"`
  - `tools:replace="android:allowBackup"` (win over plugin defaults)
- `res/xml/backup_rules.xml` — exclude root/file/database/sharedpref/external
- `res/xml/data_extraction_rules.xml` — same excludes for cloud-backup **and**
  device-transfer (API 31+)

## CI

`phase_a2_ci.yml` → flutter-checks step **Assert Android backup deny** greps
the manifest attributes and XML exclude markers.

## Remaining (ZAR-MOB-001)

- Local SQLite encryption decision + implementation
- Tamper-evident / classified export policy
- Documented recovery trade-offs for lost-device scenarios

## Client ship note

Takes effect on the **next** signed APK after merge (current device QA APK
20083 does not yet include this manifest). No server/prod change.
