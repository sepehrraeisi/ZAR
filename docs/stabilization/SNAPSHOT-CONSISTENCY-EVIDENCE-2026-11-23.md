# Consistent workspace snapshot read — Evidence (ZAR-DATA-006)

تاریخ: 2026-11-23 — شاخه: `feature/consistent-snapshot-read`
مرجع: FINDINGS ZAR-DATA-006؛ gate multi-device پس از write CAS

## Scope

- فیلد `epoch` روی `zar_workspaces` (migration `1793604703`)
- bump epoch داخل همان transaction برای upsert / allocation replace / cash append / restore commit
- مسیر `GET /api/zar/read/snapshot` با fence قبل/بعد epoch و retry محدود
- کلاینت: `ZarPocketBaseRepository.loadCompleteSnapshot` فقط از این route

## Acceptance

- `pocketbase_snapshot_consistency_test.py`: anonymous 401؛ epoch بعد از write؛
  خواندن هم‌زمان با writer هرگز note/revision مخلوط نمی‌دهد
- Flutter repository tests با fake snapshot route
- lineage شامل `1793604703`؛ restore helper hash به‌روز

## Production deploy (2026-11-23)

- PR #35 merged (`2ce0611`); required CI checks green.
- Fresh atomic backup `zar-20261123T154347Z` (`data.db` SHA-256 `b5e9e991…1932`, quick/integrity ok) + off-site under `Documents\ZAR-OffsiteBackups\zar-20261123T154347Z`.
- Rollback copies: `/var/tmp/zar-snapshot-consistency-rollback-20261123T1544Z`.
- stop → Applied `1793604703_workspace_epoch.js` as `zarapp` → start; hooks `zar_write.js` / `zar_bootstrap.js` / `zar_restore.js` / `zar_read.js` / `zar_read_routes.pb.js` installed.
- Postflight: `zar-server` active; health `200`; `NRestarts=0`; listener `127.0.0.1:8090` only; `_migrations` row present; `zar_workspaces.epoch` column present; anonymous `GET /api/zar/read/snapshot` → **401**.
