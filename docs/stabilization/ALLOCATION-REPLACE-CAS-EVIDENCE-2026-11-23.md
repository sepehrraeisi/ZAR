# Allocation replace CAS / audit — Evidence (§10.5)

تاریخ: 2026-11-23 — شاخه: `feature/allocation-replace-cas`
مرجع: ماندهٔ `DOMAIN-HARD-DELETE-EVIDENCE` (جایگزینی delete+create کلاینت)

## Scope

- مسیر جدید: `POST /api/zar/write/allocations/replace`
- CAS روی مجموعهٔ فعلی تخصیص‌های یک `settlementId` (`expectedBefore` ↔ snapshot سرور)
- Idempotency + audit before/after در `zar_write_receipts` (`collection=zar_allocations`)
- قفل Record API: `createRule`/`updateRule`/`deleteRule` = null روی `zar_allocations`
- خارج: cloud cash sync، atomic workspace bootstrap، realtime UI

## Server

- migration `1793604698_allocation_replace_cas.js`
- hooks: `zar_write.js` → `replaceAllocations`؛ route در `zar_write_routes.pb.js`
- snapshot decode: JSON fields may arrive as `types.JSONRaw` byte arrays — `zarWritePlainData` uses `toString`+`JSON.parse` (same pattern as `zar_restore.js`); without that, CAS before-hash always looked empty and stale clears falsely returned 200

## Client

- `savePaymentAllocations` دیگر batch delete/create نمی‌زند؛ replace route + 409 قابل‌بازیابی

## Acceptance

- `pocketbase_allocation_replace_cas_test.py`: replace، replay، stale 409، Record API create 403
- hard-delete suite: Record API allocation create/delete 403؛ replace route 200
- lineage شامل migration جدید
- `flutter analyze` / repository tests

## Production

- Deploy فقط بعد از CI سبز + backup تازه (این PR).
