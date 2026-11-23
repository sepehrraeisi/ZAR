# Cash append CAS / idempotency — Evidence (§10.5)

تاریخ: 2026-11-23 — شاخه: `feature/cash-append-cas`
مرجع: ماندهٔ cloud write CAS بعد از allocation + bootstrap

## Scope

- مسیر جدید: `POST /api/zar/write/cash/append`
- Idempotency + immutability (same id / different payload → 409)
- قفل Record API create روی `zar_cash_entries`
- اعتبارسنجی ساختاری kind/direction/amount روی سرور؛ parity کامل `validateCashEntries` همچنان سمت کلاینت
- خارج: باز کردن signup، realtime UI

## Server

- migration `1793604701_cash_append_cas.js`
- hooks: `zar_write.js` → `appendCash`؛ route در `zar_write_routes.pb.js`

## Client

- `appendCashEntry` از replace Record API به append route + 409 قابل‌بازیابی

## Acceptance

- `pocketbase_cash_append_cas_test.py`: Record API 403؛ append؛ replay؛ mismatch؛ immutable
- authz suite با append route
- lineage شامل migration جدید
- `flutter analyze`

## Production deploy (2026-11-23)

- PR #30 merged (`ad90263`); CI required checks green.
- Fresh atomic backup `zar-20261123T140143Z` (`data.db` SHA-256 `f3152475…b5cf`, quick/integrity ok) + off-site byte-identical under `Documents\ZAR-OffsiteBackups\zar-20261123T140143Z`.
- Rollback copies: `/var/tmp/zar-cash-append-cas-rollback-20261123T1402Z` (pre-deploy `zar_write.js` / `zar_write_routes.pb.js`).
- stop → Applied `1793604701_cash_append_cas.js` as `zarapp` → start.
- Postflight: `active`, health `200`, `NRestarts=0`, listener `127.0.0.1:8090` only; `/api/zar/write/cash/append` anonymous → **401**; `zar_cash_entries.createRule` null; migration row present.
- Artifact SHA-256 on host matched local: migration `62e31054…932d`, `zar_write.js` `d484f49a…449a`, routes `64c8fb76…6489`.
