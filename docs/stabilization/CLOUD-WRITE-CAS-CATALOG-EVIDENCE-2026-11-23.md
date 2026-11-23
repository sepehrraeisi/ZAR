# Cloud Write CAS — Catalog slice (coin/currency)

تاریخ: 2026-11-23 — شاخه: `feature/cloud-write-cas-catalog`
مرجع: اسلایس ۱ `CLOUD-WRITE-CAS-EVIDENCE-2026-11-23.md`

## Scope

- کالکشن‌ها: `zar_coin_types`, `zar_currency_types`
- همان مسیر `/api/zar/write/upsert` + `zar_write_receipts`
- خارج: allocations/cash، atomic bootstrap، production deploy این اسلایس تا CI سبز + backup تازه

## Server

- migration `1793604695_cloud_write_cas_catalog.js` (زیر lineage top، بعد از `1793604690`)
- `zar_write.js` / `zar_write_routes.pb.js`: دو کالکشن به allow-list + Record API revision guards

## Client

- `saveCoinType` / `saveCurrencyType` از `_casUpsert`؛ revision side-map از load/restore

## Acceptance

- CAS suite: create coin → revision 1؛ stale expectedRevision → 409
- lineage test شامل migration جدید
- `flutter analyze` / targeted repository tests
