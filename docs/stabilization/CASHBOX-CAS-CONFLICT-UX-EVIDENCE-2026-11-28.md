# Cashbox CAS conflict UX — Evidence

تاریخ: 2026-11-28
مرجع: conflict-reload pattern (ZAR-DATA-002); cash append + settlement CAS

## Scope

- `_CashEntrySheet` surfaces typed `ZarCloudWriteConflictException` messages.
- Reload-needed conflicts (`idempotency_payload_mismatch`, settlement
  `stale_revision`, …) clear the pending retry payload and expose
  **تازه‌سازی از سرور**.
- Non-reload cash conflicts keep the prior «تلاش دوباره همان سند» retry path
  when not a typed conflict; typed immutable conflicts show server copy.
- `CashboxScreen` receives `onReload` from the cloud shell
  (`_refreshFromServer`).
- Client-only; no server deploy.

## Client

- `lib/features/inventory/cashbox_screen.dart`
- `lib/repository_phase_a2_app_v2.dart` (wire `onReload`)
- Tests: `test/cashbox_test.dart`

## Production

- Ships with the next signed APK after 20087.
