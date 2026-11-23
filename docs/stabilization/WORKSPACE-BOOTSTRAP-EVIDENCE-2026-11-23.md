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

## Production

- Deploy فقط بعد از CI سبز + backup تازه.
