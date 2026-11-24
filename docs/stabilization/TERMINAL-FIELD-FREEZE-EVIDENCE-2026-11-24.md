# Terminal field freeze — Evidence (ZAR-DATA-008 remainder)

تاریخ: 2026-11-24 — شاخه: `feature/terminal-field-freeze`
مرجع: FINDINGS ZAR-DATA-008 (field-level rewrite on posted rows)

## Scope

- After deal/settlement reaches `completed` or `cancelled`, financial and
  identity fields are immutable via `/api/zar/write/upsert`.
- Allowed mutations: `note` + `updatedAt` only.
- Status reopen still returns `409 lifecycle_locked`.
- Field rewrite returns `409 terminal_field_locked`.
- Client maps both codes to distinct Persian conflict messages (no longer
  mislabeled as stale revision).
- Outside slice: period lock, reversal-only posted correction, audit trail.

## Server

- `server/pb_hooks/zar_write.js` → `zarWriteEnforceTerminalFieldFreeze`
  (canonical JSON compare so key order from PocketBase does not false-trip).

## Client

- `ZarCloudWriteConflictException.lifecycleLocked` /
  `.terminalFieldLocked`
- `zar_pocketbase_repository.dart` `_casUpsert` maps the new codes.

## Acceptance (local)

- `pocketbase_domain_write_invariants_test.py`: amount/direction rewrite on
  terminal rows → `terminal_field_locked`; note update on completed deal → 200.
- Sibling CAS suites remain green.

## Production deploy (2026-11-24)

- PR #41 merged (`c4317da`); required CI checks green.
- Fresh atomic backup `zar-20261124T101555Z` (`data.db` SHA-256
  `7b53fc6f…4ec6`, quick/integrity ok) + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T101555Z`.
- Rollback copy: `/var/tmp/zar-terminal-field-freeze-rollback-20261124T1017Z`
  (`zar_write.js` pre-deploy).
- Installed `zar_write.js` and restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; listener
  `127.0.0.1:8090` only; anonymous upsert → **401**.
