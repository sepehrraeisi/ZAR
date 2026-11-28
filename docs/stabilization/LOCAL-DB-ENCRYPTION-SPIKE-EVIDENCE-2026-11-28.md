# Local DB encryption spike — Evidence (ADR Option A)

تاریخ: 2026-11-28  
شاخه: `spike/local-db-encryption-sqlcipher-mc`  
مرجع: `LOCAL-DB-ENCRYPTION-ADR-2026-11-25.md` (Accepted)

## Approach

- Bundle **SQLite3MultipleCiphers** via `sqlite3` build hooks
  (`hooks.user_defines.sqlite3.source: sqlite3mc`) — Drift’s current
  recommended path (not legacy `sqlcipher_flutter_libs`).
- Keystore-derived passphrase in `ZarLocalDbKeyStore`
  (`zar.local.db.passphrase.v1` via `ZarSecureTokenStore`).
- Production opener `ZarLocalDatabase.openForDevice()`:
  - **Android + release**: migrate `zar_plus_local.sqlite` →
    `zar_plus_local_enc.sqlite` (`VACUUM INTO` + `PRAGMA rekey`), then open
    with `PRAGMA key`.
  - **Debug / non-Android / tests**: plaintext `driftDatabase(name: 'zar_plus_local')`.
- `main.dart` local + Firebase paths use `openForDevice()`.

## Tests

```text
flutter test test/zar_local_db_encryption_test.dart
+ zarEscapeSqlString doubles single quotes
+ ZarLocalDbKeyStore persists passphrase across reads
+ plaintext → encrypted migration when cipher is available
All tests passed!
```

Migration case exercised real `PRAGMA cipher` + wrong-key failure + correct-key
read on this host (cipher available after hooks).

## Out of scope / follow-up

- Device QA APK proving encrypted file on-phone (next APK after merge).
- Cloud shell / PocketBase path still does not open Drift in `main` — local
  encryption applies to local-first entrypoints first.
- Export JSON remains plaintext-by-design (ADR non-goal).
- Second-operator drills still require a separate human
  (`OPERATORS-DRILL-TRACKER-2026-11-25.md`).

## Files

- `lib/data/local/zar_local_db_key_store.dart`
- `lib/data/local/zar_local_db_encryption.dart`
- `lib/data/local/zar_local_database.dart` (`openForDevice`)
- `lib/main.dart`
- `pubspec.yaml` (`sqlite3` + hooks)
- `test/zar_local_db_encryption_test.dart`
