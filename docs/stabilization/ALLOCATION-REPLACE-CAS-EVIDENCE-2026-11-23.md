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

## Production deploy (2026-11-23)

- PR #26 merged (`26a82f0`); CI required checks green.
- Fresh atomic backup `zar-20261123T133036Z` (`data.db` SHA-256 `3fcf2ecc…52ea`, quick/integrity ok) + off-site byte-identical under `Documents\ZAR-OffsiteBackups\zar-20261123T133036Z`.
- Rollback copies: `/var/tmp/zar-alloc-replace-cas-rollback-20261123T1331Z` (pre-deploy `zar_write.js` / `zar_write_routes.pb.js`).
- stop → Applied `1793604698_allocation_replace_cas.js` as `zarapp` → start.
- Postflight: `active`, health `200`, `NRestarts=0`, listener `127.0.0.1:8090` only; `/api/zar/write/allocations/replace` anonymous → **401**; `zar_allocations` create/update/delete rules null; migration row present.
- Artifact SHA-256 on host matched local: migration `8192458e…f8c6`, `zar_write.js` `7577e548…842c`, routes `a8565084…beae`.
