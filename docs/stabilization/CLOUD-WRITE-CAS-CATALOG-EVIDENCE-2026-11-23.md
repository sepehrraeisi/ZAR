# Cloud Write CAS — Catalog slice (coin/currency)

تاریخ: 2026-11-23 — شاخه: `feature/cloud-write-cas-catalog`
مرجع: اسلایس ۱ `CLOUD-WRITE-CAS-EVIDENCE-2026-11-23.md`

## Scope

- کالکشن‌ها: `zar_coin_types`, `zar_currency_types`
- همان مسیر `/api/zar/write/upsert` + `zar_write_receipts`
- خارج: allocations/cash، atomic bootstrap

## Server

- migration `1793604695_cloud_write_cas_catalog.js` (زیر lineage top، بعد از `1793604690`)
- `zar_write.js` / `zar_write_routes.pb.js`: دو کالکشن به allow-list + Record API revision guards

## Client

- `saveCoinType` / `saveCurrencyType` از `_casUpsert`؛ revision side-map از load/restore

## Acceptance

- CAS suite: create coin → revision 1؛ stale expectedRevision → 409
- lineage test شامل migration جدید
- `flutter analyze` / targeted repository tests

## Production deploy (2026-11-23)

- PR #24 merged (`48a44bc`); backup `zar-20261123T130106Z` (SHA `55e74ce6…268a`, quick/integrity ok) + off-site byte-identical
- stop → Applied `1793604695_cloud_write_cas_catalog.js` as `zarapp` → start
- Postflight: active, health 200, `NRestarts=0`, loopback `:8090`, upsert anonymous 401; coin/currency `revision < 1` = 0
- Rollback copies: `/var/tmp/zar-cloud-write-cas-catalog-rollback-20261123T1301Z`
