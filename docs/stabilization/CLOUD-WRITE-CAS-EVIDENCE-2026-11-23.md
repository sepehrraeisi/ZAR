# Cloud Write CAS / Idempotency — Evidence (§10.5 slice 1)

تاریخ: 2026-11-23 — شاخه: `feature/cloud-write-cas`
مرجع: `PROGRAMMER-HANDOFF.md` §10.5، ماندهٔ مستند در `DOMAIN-HARD-DELETE-EVIDENCE-2026-11-06.md`

## Scope این اسلایس

- کالکشن‌ها: `zar_people`, `zar_deals`, `zar_settlements`
- مسیر اصلی کلاینت: `POST /api/zar/write/upsert` (CAS + idempotency)
- خارج از اسلایس: coin/currency/allocations/cash، atomic workspace bootstrap، realtime multi-device UI

## Server

- migration `server/pb_migrations/1793604690_cloud_write_cas.js` (زیر lineage top `1793604800`):
  - فیلد top-level `revision` روی سه کالکشن + backfill `1`
  - کالکشن خصوصی `zar_write_receipts` (API rules همه null؛ فقط via hooks)
- hooks: `server/pb_hooks/zar_write.js`, `zar_write_routes.pb.js`
  - upsert: `expectedRevision` باید با مقدار فعلی یکی باشد؛ موفقیت → `revision+1` + receipt
  - replay همان `idempotencyKey` + همان request hash → پاسخ قبلی بدون دوباره‌نویسی
  - mismatch key/payload یا stale revision → **409** با JSON در `message` (PocketBase `ApiError.data` برای اعداد قابل اتکا نیست)
  - Record API update بدون `revision` → **400**؛ mismatch → **409**
- restore path: ردیف‌های restore‌شده `revision=1` می‌گیرند

## Client

- `ZarPocketBaseRepository` برای people/deals/settlements از `/api/zar/write/upsert` استفاده می‌کند
- side-map `revision` از `loadCompleteSnapshot` / پاسخ موفق upsert / بعد از restore
- `ZarCloudWriteConflictException` پیام فارسی + بدون overwrite خاموش
- `ZarWriteCoordinator` conflict را blind-retry نمی‌کند؛ UI پیام conflict را نشان می‌دهد

## Acceptance proof (local / CI)

- `python server/tests/pocketbase_cloud_write_cas_test.py --pocketbase <0.40.4>`:
  - create → revision 1
  - idempotent replay
  - idempotency payload mismatch → 409
  - update → revision 2
  - stale expectedRevision → 409 + `currentRevision=2`
  - Record API PATCH بدون revision → 400
- CI job `pocketbase-authorization` این suite را اجرا می‌کند
- Flutter: repository + write-coordinator unit tests برای مسیر CAS / 409 / non-retryable conflict

## Production deploy (2026-11-23)

- Owner authority: explicit full-authority direction to ship; CI green on merged PR #23 (`11f0d4c`).
- Fresh atomic backup `zar-20261123T124303Z` (`data.db` SHA-256 `fa456f6d…df667`, `quick_check=ok`, `integrity_check=ok`) + off-site byte-identical copy under `Documents\ZAR-OffsiteBackups\zar-20261123T124303Z`.
- Rollback path: restore from that snapshot (forward-only lineage forbids down-migrating under restore top after receipts); pre-deploy hook copies at `/var/tmp/zar-cloud-write-cas-rollback-20261123T1245Z`.
- Install (root:root 0644): migration `1793604690_cloud_write_cas.js`, hooks `zar_write.js` / `zar_write_routes.pb.js`, updated `zar_restore.js`.
- stop → `migrate up` as `zarapp` → Applied `1793604690_cloud_write_cas.js` → start.
- Postflight: `active`, health `200`, `NRestarts=0`, listener `127.0.0.1:8090` only; `/api/zar/write/upsert` anonymous → **401** (route live); collections include `zar_write_receipts`; people/deals/settlements with `revision < 1` = **0**.
