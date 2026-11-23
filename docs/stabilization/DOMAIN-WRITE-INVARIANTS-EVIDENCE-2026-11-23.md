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

## Production deploy (2026-11-23)

- PR #37 merged (`dbea600`); required CI checks green.
- Fresh atomic backup `zar-20261123T160955Z` (`data.db` SHA-256 `7b53fc6f…4ec6`, quick/integrity ok) + off-site under `Documents\ZAR-OffsiteBackups\zar-20261123T160955Z`.
- Rollback copy: `/var/tmp/zar-domain-invariants-rollback-20261123T1610Z` (`zar_write.js`).
- Installed `zar_write.js` and restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; listener `127.0.0.1:8090` only; anonymous upsert → **401**.
