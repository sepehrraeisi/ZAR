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

## Production deploy (2026-11-24)

- PR #52 merged (`ca1e452`); required CI checks green.
- Fresh atomic backup `zar-20261124T142824Z` (`data.db` SHA-256
  `7b53fc6f…4ec6`, quick/integrity ok) + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T142824Z`.
- Rollback copy: `/var/tmp/zar-restore-amount-share-rollback-20261124T1432Z`
  (`zar_restore.js` pre-deploy).
- Installed `zar_restore.js` (depends on existing `zar_domain_validate.js`);
  restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; listener
  `127.0.0.1:8090` only; anonymous restore state → **401**.
