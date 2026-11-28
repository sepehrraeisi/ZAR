# Device actor attribution (Option B) — Evidence

تاریخ: 2026-11-28  
مرجع: ADR Accepted `DEVICE-ACTOR-ATTRIBUTION-ADR-2026-11-25.md`

## Scope (this change)

- Domain optional `createdFromDevice` / `updatedFromDevice` on people, deals,
  settlements (`ZarDeviceRef`: short opaque `installationId` + `label`).
- Keystore-backed `ZarDeviceAttributionStore` (raw UUID private; hash exported).
- Bridge + cashbox settlement create stamp the current device.
- Backup codec V8+ optional encode/decode.
- Server: shape validate + `createdFromDevice` immutable on update; terminal
  freeze includes the field for deals/settlements.
- Client/docs only for label editor UI (follow-up: BackupScreen تنظیمات).

## Out of scope here

- Drift local column persistence of device stamps (cloud JSON is source of
  truth; local cache may drop the fields until a later Drift migration).
- Android `Build.model` default (uses `Android` until label UI / device_info).
- Production advertise of multi-device (wait APK + device QA).

## Tests

- `test/zar_device_attribution_test.dart`
- PocketBase authz/domain suites via CI (`pocketbase-authorization`)

## Deploy

- Hook-only server change (no collection migration) co-deployed with signup
  reopen on 2026-11-28 after backup `zar-20261128T142753Z` + off-site verify.
- Installed `zar_domain_validate.js` (`3d34501b…aa0ff`) + `zar_write.js`
  (`04d9bf90…cf1818`); rollback
  `/var/tmp/zar-signup-attr-rollback-20261128T1437Z`.
- Postflight shared with `SIGNUP-REOPEN-DEPLOY-EVIDENCE-2026-11-28.md`.
- Client APK ≥ **20089** still required before advertising multi-device.
