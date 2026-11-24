# Drop transitional `local-user` create allowance — Evidence (ZAR-DATA-003)

تاریخ: 2026-11-24 — شاخه: `feature/drop-transitional-local-user-actor`
مرجع: `CREATE-TIME-ACTOR-STAMP-EVIDENCE-2026-11-24.md` (remove after APK with uid stamp)

## Scope

- `zarDomainEnforceActor` accepts only `createdBy === auth uid` on create.
- Forged / stale `local-user` creates → **400**.
- Existing rows with `createdBy: local-user` remain readable; updates still
  require immutable match to the stored value.
- Prerequisite: Device QA APK **20083** installed on owner Samsung (cloud
  shell stamps PocketBase uid).
- Outside slice: physical multi-device soak; older APKs must upgrade before
  creating new cloud rows.

## Server

- `server/pb_hooks/zar_domain_validate.js`
- `server/tests/pocketbase_domain_write_invariants_test.py`

## Acceptance

- Domain write invariants: `local-user` create denied; matching uid create ok
- Production postflight after hook install + restart
