# Atomic workspace bootstrap — Evidence (§10.5 / ZAR-DATA-005)

تاریخ: 2026-11-23 — شاخه: `feature/atomic-workspace-bootstrap`
مرجع: `FINDINGS.md` ZAR-DATA-005

## Scope

- مسیر جدید: `POST /api/zar/bootstrap/workspace`
- Create+pin اتمیک در یک تراکنش؛ id قطعی `ws{userId}` برای هم‌گرایی concurrent
- Replay وقتی `users.workspace` از قبل set است؛ Record API create روی `zar_workspaces` قفل
- خارج: باز کردن signup، cash CAS، realtime UI

## Server

- migration `1793604699_atomic_workspace_bootstrap.js` (`createRule=null`)
- hooks: `zar_bootstrap.js` + `zar_bootstrap_routes.pb.js`

## Client

- `ZarPocketBaseWorkspaceBootstrapper` فقط از route استفاده می‌کند (دیگر create+PATCH جدا نیست)

## Acceptance

- `pocketbase_workspace_bootstrap_test.py`: Record API 403؛ create؛ pin؛ replay؛ بدون duplicate
- authz / write CAS / allocation / hard-delete / restore suites با bootstrap
- lineage شامل migration جدید
- `flutter analyze`

## Production deploy (2026-11-23)

- PR #28 merged (`35bba68`); CI required checks green.
- Fresh atomic backup `zar-20261123T134845Z` (`data.db` SHA-256 `5ecda448…99fb`, quick/integrity ok) + off-site byte-identical under `Documents\ZAR-OffsiteBackups\zar-20261123T134845Z`.
- Rollback notes: `/var/tmp/zar-bootstrap-rollback-20261123T1349Z` (pre-deploy hooks listing; bootstrap files were new installs).
- stop → Applied `1793604699_atomic_workspace_bootstrap.js` as `zarapp` → start.
- Postflight: `active`, health `200`, `NRestarts=0`, listener `127.0.0.1:8090` only; `/api/zar/bootstrap/workspace` anonymous → **401**; `zar_workspaces.createRule` null; migration row present.
- Artifact SHA-256 on host matched local: migration `49f3553d…ff46`, `zar_bootstrap.js` `882ba34c…642f`, routes `0b221080…958d`.
