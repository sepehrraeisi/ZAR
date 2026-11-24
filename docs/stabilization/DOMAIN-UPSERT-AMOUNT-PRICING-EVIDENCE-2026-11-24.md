# Domain upsert amount/pricing parity — Evidence (ZAR-DATA-003)

تاریخ: 2026-11-24 — شاخه: `feature/domain-upsert-amount-pricing`
مرجع: FINDINGS ZAR-DATA-003 (deep amount/pricing remainder)

## Scope

- Deep amount/pricing validation on `/api/zar/write/upsert` for deals and
  settlements, shared via `zar_domain_validate.js` (currency uppercase code +
  minor units/scale, gold decimal/unit/purity, coin lines + coin-type refs,
  deal pricing kind/total consistency).
- `createdBy` immutability on update (create still allows client stamp
  `local-user`; auth-id match deferred until client stamps real actor).
- Outside slice: restore-module consolidation, period lock, full audit trail,
  forged-actor-on-create hardening.

## Server

- `server/pb_hooks/zar_domain_validate.js` (new shared module)
- `server/pb_hooks/zar_write.js` → wires domain validate into upsert

## Acceptance (local)

- `pocketbase_domain_write_invariants_test.py`: lowercase currency / negative
  minor units / pricing kind mismatch / missing coin type / bad gold decimal
  → 400; `createdBy` rewrite → 400; lifecycle locks unchanged.
- Sibling suites green: allocation replace CAS, snapshot consistency,
  multi-device CAS soak, cloud write CAS.

## Production deploy

- Pending PR merge + backup discipline (filled after deploy).
