# Restore ↔ upsert amount structural share — Evidence (ZAR-DATA-003)

تاریخ: 2026-11-24 — شاخه: `feature/restore-domain-amount-share`
مرجع: FINDINGS ZAR-DATA-003 (restore-module share remainder)

## Scope

- `zar_restore.js` calls `zar_domain_validate.parseAssetAmount` as a
  structural gate before restore-specific quantity accounting.
- Keeps currency/gold/coin shape checks from drifting between
  `/api/zar/write/upsert` and transactional restore.
- Restore still owns quantity scaling / gold gram conversion / pricing totals
  (full pricing consolidation deferred — purity-unknown edge differs).
- Canary artifact pins updated: `helperHook` SHA + guarded-script manifest pin.

## Server

- `server/pb_hooks/zar_restore.js` → `zarRestoreDomainAmountGate`
- `server/scripts/transactional_restore_expected_state.json`
- `server/scripts/guarded_transactional_restore_{deploy,rollback,contain}.sh`

## Acceptance

- `transactional_restore_expected_state_test` green
- `pocketbase_transactional_restore_test.py` green
- domain write invariants remain green

## Production deploy

- Pending PR merge + backup discipline (filled after deploy).
