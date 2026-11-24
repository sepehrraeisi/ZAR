# Conflict reload UX — Evidence (ZAR-DATA-002 remainder)

تاریخ: 2026-11-24 — شاخه: `feature/conflict-reload-ux`
مرجع: FINDINGS ZAR-DATA-002 (conflict workflow before advertising multi-device)

## Scope

- Cloud write conflicts that require a fresh working copy
  (`stale_revision`, `lifecycle_locked`, `terminal_field_locked`,
  `idempotency_payload_mismatch`) expose a SnackBar action **تازه‌سازی**.
- Action reloads `loadCompleteSnapshot` via store `refresh`, reconciles
  reminders, and prompts the user to re-enter the edit — never blind-retries
  the stale payload.
- Outside slice: PocketBase realtime subscriptions, physical multi-device soak.

## Client

- `ZarCloudWriteConflictException.needsReload`
- `repository_phase_a2_app_v2.dart` `_runWrite` / `_reloadAfterConflict`
- Tests: `test/zar_cloud_write_conflict_test.dart`

## Acceptance

- Unit: conflict codes mark `needsReload` correctly.
- Manual/device: concurrent edit → snackbar → تازه‌سازی → local state matches
  server revision before retry.

## Production

- Client-only; no server deploy. Ships with the next signed APK.
