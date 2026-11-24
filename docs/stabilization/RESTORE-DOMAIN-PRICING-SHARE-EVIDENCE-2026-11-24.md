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

## Production deploy (2026-11-24)

- PR #54 merged (`7202dd3`); required CI checks green.
- Fresh atomic backup `zar-20261124T144850Z` (`data.db` SHA-256
  `7b53fc6f…4ec6`, quick/integrity ok) + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T144850Z`.
- Rollback copy: `/var/tmp/zar-restore-pricing-share-rollback-20261124T1450Z`
  (`zar_restore.js` + `zar_domain_validate.js` pre-deploy).
- Installed `zar_restore.js` + `zar_domain_validate.js` (SHA-256
  `1dc656fe…109ef` / `c8371e7e…e2f7`); restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; listener
  `127.0.0.1:8090` only; anonymous restore state → **401**.
