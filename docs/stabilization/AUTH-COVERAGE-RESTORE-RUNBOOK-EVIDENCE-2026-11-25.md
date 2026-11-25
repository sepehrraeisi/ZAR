# Auth coverage + restore runbook hygiene (P2)

تاریخ: 2026-11-25 — شاخه: `feature/auth-coverage-restore-runbook-hygiene`

## Auth suite expansion

`test/zar_pocketbase_auth_service_test.dart` now covers (beyond 429 mapping):

- sign-in 400 → wrong-credentials Persian message
- sign-in 503 → connection Persian message
- sign-up 400 → duplicate/short-password Persian message
- sign-in / sign-out `authStateChanges` emission
- `restoreSession` empty store no-op
- `restoreSession` 403 clears secure store
- `restoreSession` 503 keeps token (transient)
- `restoreSession` hydrates `currentUser` on valid token

Existing Keystore migration suite (`zar_token_store_migration_test.dart`) remains green.

Local: `flutter test test/zar_pocketbase_auth_service_test.dart test/zar_token_store_migration_test.dart` → 16 passed.

## Restore runbook hygiene

`RESTORE-RUNBOOK.md` «Remaining disaster-recovery gaps» updated:

- Acknowledge off-site pull (`pull-offsite-backups.ps1`) already exists
- Add explicit **second-operator restore drill** checklist (clone only; no prod)
- Clarify remaining owner gaps (encryption-at-rest, RPO/RTO, second-operator log)

## Remaining

- Second operator must execute and log the drill
- Broader coverage still open for cloud shell / backup UI / repository
