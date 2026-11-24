# createdAt immutability on upsert — Evidence (ZAR-DATA-003)

تاریخ: 2026-11-24 — شاخه: `feature/created-at-immutable`
مرجع: FINDINGS ZAR-DATA-003 (forged identity timestamps)

## Scope

- `/api/zar/write/upsert` rejects updates that rewrite `data.createdAt`
  (`400 … createdAt is immutable`) for people/deals/settlements/catalog
  payloads once a row exists.
- Create still stamps client `createdAt`; `updatedAt` remains mutable.
- Outside slice: restore-module share, period lock, audit trail.

## Server

- `server/pb_hooks/zar_write.js` → `zarWriteEnforceCreatedAtImmutable`

## Acceptance

- `pocketbase_domain_write_invariants_test.py`: person `createdAt` rewrite → 400.

## Production deploy

- Pending PR merge + backup discipline (filled after deploy).
