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

## Production deploy

- Pending PR merge + backup discipline (filled after deploy).
