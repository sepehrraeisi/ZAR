# Signup reopen + attribution hooks — Production deploy evidence

تاریخ: 2026-11-28  
مرجع: Owner authorization (`SIGNUP-REOPEN-LAUNCH-PACKET-2026-11-25.md`);
PR #77 (`1793604704`); PR #93 (device attribution hooks).

## Scope

- Forward migration `1793604704_open_public_signup.js` → `users.createRule = ''`
  (public create open marker).
- Hook install: `zar_domain_validate.js` + `zar_write.js` (Option B
  `createdFromDevice` / `updatedFromDevice` immutability + freeze).
- Postflight: health, listener, anonymous create smoke, rate-limit 429.

## Preconditions

- Master tip: `c22b832` (merge #93 after #77).
- Fresh atomic backup `zar-20261128T142753Z`
  (`data.db` SHA-256 `8555e7f2…54c14`, `quick_check=ok`, `integrity_check=ok`).
- Off-site byte-identical under
  `Documents\ZAR-OffsiteBackups\zar-20261128T142753Z` (pull script SUCCESS).

## Deploy

- Rollback copies:
  `/var/tmp/zar-signup-attr-rollback-20261128T1437Z`
  (pre-deploy `zar_domain_validate.js` / `zar_write.js`).
- stop → Applied `1793604704_open_public_signup.js` as `zarapp` → start.
- Artifact SHA-256 on host matched local:
  - migration `e0bb3735…c5ba8`
  - `zar_domain_validate.js` `3d34501b…aa0ff`
  - `zar_write.js` `04d9bf90…cf1818`

## Postflight

- `zar-server` active; health `200`; `NRestarts=0`; listener
  `127.0.0.1:8090` only.
- `_migrations` includes `1793604704` and lineage tip
  `1793604800_transactional_restore.js` still present.
- `users.createRule` = empty string (`''`).
- Anonymous upsert → **401**; public health → **200**.
- Signup burst (8 anonymous creates via
  `https://app.titangold.ir/api/collections/users/records`):
  statuses **200×5, 429×2** (plus one transport abort after limit) —
  matches versioned `users:create` rule (5 / 600s).
- Smoke accounts (`smoke4704+*@zarplus.cloud`) deleted after verify;
  `PRAGMA quick_check` ok; service restarted (`NRestarts=0`).

## Rollback path

1. stop → `migrate down 1` (re-closes createRule to null) **or** restore
   backup `zar-20261128T142753Z` if broader recovery needed.
2. Restore hooks from
   `/var/tmp/zar-signup-attr-rollback-20261128T1437Z`.
3. start → confirm createRule null + health.

## Follow-up

- Client APK ≥ **20089** with attribution stamps + signup UI (PR #77 gate).
- Device QA on Samsung + moto e13 before advertising multi-device.
