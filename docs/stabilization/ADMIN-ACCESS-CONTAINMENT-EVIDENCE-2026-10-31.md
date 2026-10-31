# ZAR+ PocketBase Administrative Access Containment Evidence

Date: 2026-10-31 12:19 +03:30 (Asia/Tehran)
Production window: 2026-10-31 08:49:04–08:49:13 UTC
Source commit before evidence update: `859ece7`
Result: **PASS — rollback was not required**

## Scope

This change removed the PocketBase dashboard, superuser login/records and
management APIs from the public HTTPS surface while preserving normal mobile
authentication/data routes. Operator access remains available only by an SSH
local tunnel to PocketBase's loopback listener.

The second layer configures PocketBase to trust only a private client-IP header
that Caddy always replaces and limits authenticated superuser requests to
loopback. This protects ordinary record routes too if a superuser token is ever
stolen.

## Reviewed artifacts

- Caddy template: `server/deploy/Caddyfile`
- Settings migration: `server/pb_migrations/1793394000_trust_caddy_client_ip.js`
- Change and rollback plan: `docs/stabilization/ADMIN-ACCESS-CONTAINMENT-PLAN.md`
- Production evidence directory: `/root/zar-admin-access-20261031T084900Z`
- Off-server evidence archive:
  `work/admin-access-20261031T084900Z/zar-admin-access-20261031T084900Z-evidence.tar`
- Archive SHA-256:
  `829cdb75714cef87e704a7d2d82f92e1a89ace48deb7553059bc309b6cee941a`

Artifact hashes deployed:

```text
4586188b7917619a54e3c48c8aad14751ed4807118a78f33ae7a0d84b9bced65  /etc/caddy/Caddyfile
4eea6b69a89fe07de0aeed734e6f85c4d102fbac2525b15f4d7b9effc350f0fc  /opt/zar/server/pb_migrations/1793394000_trust_caddy_client_ip.js
```

## Pre-production proof

- The installed Caddy 2.8.4 binary validated and formatted the candidate.
- A loopback-only Caddy canary preserved health, normal auth and record routes
  while returning `404` for every reviewed management route, including
  impersonation, encoded paths, the `_superusers` name and its fixed PocketBase
  collection ID `pbc_3142635823`.
- The settings migration was applied to an isolated copy of production data.
  An authenticated clone-only superuser received `200` from loopback and `403`
  when `X-Zar-Client-IP` contained a non-loopback address.
- A separate integration test proved Caddy overwrites a forged incoming private
  header. Migration `down 1` restored `[]|0|[]`, removed the history row and left
  SQLite integrity `ok`. Every disposable unencrypted data copy was removed.
- Two review findings were fixed before deployment: the initial missing
  impersonation route and the collection-ID alias for `_superusers`.
- Two preflight attempts stopped before changing production and are marked
  `ABORTED.txt`: `/root/zar-admin-access-20261030T202400Z` used an invalid
  format-output assertion, and `/root/zar-admin-access-20261031T084800Z` hit
  Linux protected-regular handling for a user-owned `/tmp` file. The successful
  run performed the format check on a root-owned evidence copy.

## Recovery gate

- The first natural timer-triggered backup ran at `2026-10-31 03:01:02 UTC` and
  reported `BACKUP_OK`.
- A fresh pre-change snapshot ran at `2026-10-31 08:48:03 UTC`:
  `/backups/zar-daily/zar-20261031T084803Z/data.db`.
- Snapshot SHA-256:
  `1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8`.
- `SHA256SUMS`, immutable `quick_check` and `integrity_check` all passed.
- The exact prior Caddyfile, sanitized settings, routes, migration history,
  counts, listeners and service state are retained in the evidence directory.

## Production result

- Caddy reloaded without restart; PocketBase restart-to-healthy was `559 ms`.
- Public normal routes retained their baseline behavior:
  health/auth-methods/record-list `200`, invalid normal login `400`.
- Both public hosts return `404` for the dashboard. The full public deny matrix
  also returned `404` for superuser name/ID login and records, settings, logs,
  backups, crons, SQL, collection schema/import/truncate/meta routes and record
  impersonation. Encoding, case and double-slash probes did not bypass it.
- A separate method-correct `PUT /api/collections/import` probe returned public
  `404` and direct-loopback `401`; it is preserved in
  `additional-route-verification.txt`.
- Direct loopback and SSH-tunnel checks retained dashboard `200`, health `200`
  and unauthenticated settings `401`.
- PocketBase settings are exactly:
  `trustedProxy.headers=["X-Zar-Client-IP"]`,
  `useLeftmostIP=false`, and
  `superuserIPs=["127.0.0.1","::1"]`.
- The applied migration history gained exactly
  `1793394000_trust_caddy_client_ip.js`.
- An outside-workstation login probe was logged as `NON_LOOPBACK`; public traffic
  is no longer misclassified as `127.0.0.1`.
- External TCP 8090 remained unreachable and the listener remained
  `127.0.0.1:8090` only.
- All eight domain table counts were unchanged:
  `1,1,0,1,0,0,0,0` in the established table order.
- SQLite quick/integrity checks passed; Caddy, PocketBase and the backup timer
  remained active; `NRestarts=0`; bounded error-priority journals were empty.

Caddy emitted its existing non-fatal storage-cleaning warning about an invalid
instance UUID during reload. TLS, certificate management, reload, health and
all acceptance gates passed; the warning remains an operational follow-up.

## Rollback status

Production rollback was not required and therefore was not executed. Migration
`down 1` and restoration of the exact baseline settings were tested only on an
isolated production-data clone. The deployment had a prepared guard that would
keep filtering Caddy active and refuse automatic rollback on migration/settings
drift. The exact reproducible guarded commands are now versioned in
`ADMIN-ACCESS-CONTAINMENT-PLAN.md`.

## Remaining risk

- PocketBase rate limiting is still disabled. It can now be tuned safely because
  Real-IP handling is proven, but it requires a separate canary and rollback.
- Public user signup remains a deliberate unresolved product/security decision.
- There is no external alert destination for auth anomalies, service health or
  backup age.
- This containment does not solve the open multi-device concurrency,
  server-side invariant, audit/reversal or mobile data-protection findings.
