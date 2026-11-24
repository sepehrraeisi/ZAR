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

## Production deploy (2026-11-24)

- PR #48 merged (`b645be0`); required CI checks green.
- Fresh atomic backup `zar-20261124T130837Z` (`data.db` SHA-256
  `7b53fc6f…4ec6`, quick/integrity ok) + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T130837Z`.
- Rollback copy: `/var/tmp/zar-created-at-immutable-rollback-20261124T1310Z`
  (`zar_write.js` pre-deploy).
- Installed `zar_write.js` and restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; listener
  `127.0.0.1:8090` only; anonymous upsert → **401**.
