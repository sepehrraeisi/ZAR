# Restore ↔ upsert deal-pricing structural share — Evidence (ZAR-DATA-003)

تاریخ: 2026-11-24 — شاخه: `feature/restore-domain-pricing-share`
مرجع: FINDINGS ZAR-DATA-003 (restore pricing consolidation remainder)

## Scope

- `zar_restore.js` calls `zar_domain_validate.validateDealPricing` as a
  structural gate before restore-specific pricing accounting.
- Aligns the gold **purity-unknown** edge: restore now allows
  `amount.purity === 'unknown'` with a concrete pricing fineness (same as
  ordinary upsert), so cloud backups of incomplete-purity gold deals restore.
- Restore still owns string totals and perGram coin metadata checks that
  upsert does not need.
- Canary artifact pins updated: `helperHook` SHA + guarded-script manifest pin.
- Domain write invariants cover unknown-purity gold upsert acceptance.

## Server

- `server/pb_hooks/zar_domain_validate.js` → export `validateDealPricing`
- `server/pb_hooks/zar_restore.js` → `zarRestoreDomainPricingGate`
- `server/scripts/transactional_restore_expected_state.json`
- `server/scripts/guarded_transactional_restore_{deploy,rollback,contain}.sh`
- `server/tests/pocketbase_domain_write_invariants_test.py`

## Acceptance

- `transactional_restore_expected_state_test` green
- `pocketbase_transactional_restore_test.py` green (CI)
- `pocketbase_domain_write_invariants_test.py` green (CI; includes unknown purity)
