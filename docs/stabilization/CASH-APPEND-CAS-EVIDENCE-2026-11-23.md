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

## Production

- Deploy فقط بعد از CI سبز + backup تازه.
