# Domain write invariants — Evidence (ZAR-DATA-003 / §008 slice)

تاریخ: 2026-11-23 — شاخه: `feature/domain-write-invariants`
مرجع: FINDINGS ZAR-DATA-003 + terminal lifecycle از ZAR-DATA-008

## Scope

- اعتبارسنجی ساختاری روی `/api/zar/write/upsert` برای people/deals/settlements
  و catalog: id بیرونی/داخلی، enumها، فیلدهای اجباری، ارجاع person در workspace
- قفل lifecycle: deal/settlement با status پایانی (`completed`/`cancelled`)
  قابل reopen نیستند → HTTP 409 `lifecycle_locked`
- خارج از اسلایس: deep amount/pricing parity (restore)، period lock کامل،
  audit trail کامل

## Server

- `server/pb_hooks/zar_write.js` → `zarWriteValidateUpsertData` +
  `zarWriteEnforceTerminalLifecycle`

## Acceptance

- `pocketbase_domain_write_invariants_test.py`: mismatch/enum/missing person
  → 400؛ reopen terminal → 409 `lifecycle_locked`
- suites موجود CAS/allocation با person واقعی سبز می‌مانند

## Production

- Deploy فقط hooks (بدون migration جدید) بعد از CI + backup.
