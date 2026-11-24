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

## Production deploy

- Pending PR merge + backup discipline (filled after deploy).
