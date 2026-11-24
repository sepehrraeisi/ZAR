# Create-time actor stamp — Evidence (ZAR-DATA-003 remainder)

تاریخ: 2026-11-24 — شاخه: `feature/create-time-actor-stamp`
مرجع: FINDINGS ZAR-DATA-003 (forged actor on create)

## Scope

- Cloud shell stamps PocketBase `user.uid` onto new people/deals/settlements
  (`createdBy` / `completedBy`) via `ZarAccountSection.userId` → bridge →
  store `actorId`.
- Server upsert rejects forged create `createdBy` values (`400`). During APK
  rollout, create still accepts authenticated actor **or** transitional
  stamp `local-user` so older installs keep working. Update immutability
  unchanged; legacy rows keep their stamp.
- Local preview without account still uses `local-user` (Drift only).

## Files

- Client: `zar_cloud_shell.dart`, `backup_screen.dart` (`ZarAccountSection`),
  `repository_phase_a2_app_v2.dart`, `zar_phase_a2_store.dart`,
  `cashbox_screen.dart`, `main.dart`
- Server: `zar_domain_validate.js` `zarDomainEnforceActor`
- Tests: `pocketbase_domain_write_invariants_test.py` forged-create case

## Production deploy (2026-11-24)

- PR #43 merged (`7647a1b`) then transitional hotfix PR #44 (`a11ef31`
  merge). Required CI green on both.
- Fresh atomic backup before first install: `zar-20261124T103605Z`
  (`data.db` SHA-256 `7b53fc6f…4ec6`, quick/integrity ok) + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T103605Z`.
- Rollback copies:
  `/var/tmp/zar-create-time-actor-rollback-20261124T1040Z` and
  `/var/tmp/zar-actor-transition-rollback-20261124T1041Z`.
- Installed `zar_domain_validate.js` (strict, then transitional
  `local-user` allow) and restarted `zar-server` (no migration).
- Postflight: active; health `200`; `NRestarts=0`; anonymous upsert → **401**.
- Note: remove `local-user` create allowance only after a signed APK with
  auth-uid stamping is installed on devices.
