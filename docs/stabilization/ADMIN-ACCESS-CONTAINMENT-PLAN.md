# ZAR+ PocketBase Administrative Access Containment Plan

Status: prepared; execute as one reviewed proxy/settings change after backup and Caddy validation.

## Objective

Remove the PocketBase dashboard, superuser authentication and built-in management APIs from the public HTTPS surface while preserving all normal mobile auth/data routes and retaining operator access through an SSH local tunnel directly to loopback.

## Evidence and route scope

PocketBase 0.40.4 official source registers these superuser-only route groups:

- dashboard: `/_/`;
- settings: `/api/settings`;
- collection schema management: `/api/collections` and one-collection/truncate/meta/import routes;
- request logs: `/api/logs`;
- PocketBase-native backups: `/api/backups`;
- cron management: `/api/crons`;
- SQL execution: `/api/sql`;
- superuser auth/records: `/api/collections/_superusers/...`;
- record impersonation: `/api/collections/{collection}/impersonate/{recordId}`.

Normal client routes that must remain public include:

- `/api/health`;
- `/api/collections/users/auth-*`;
- `/api/collections/{collection}/records...`;
- `/api/files...`, `/api/realtime`, `/api/batch` and OAuth callbacks where configured.

Caddy 2 path matching normalizes request paths and exact/prefix/regular-expression matchers are used here to separate schema-management paths from record/auth paths.

## Verified starting state

- PocketBase listens only on `127.0.0.1:8090` behind Caddy.
- Caddy publicly proxies every path without filtering.
- Public dashboard returns HTTP 200.
- Public dummy superuser login reaches PocketBase and returns its normal invalid-credential response.
- PocketBase `superuserIPs` is empty.
- PocketBase `trustedProxy.headers` is empty, so its current `RealIP()` fallback sees
  all Caddy traffic as loopback. The whitelist must not be enabled until the
  trusted real-IP boundary is configured in the same gated change.
- Built-in rate-limit rules exist but `rateLimits.enabled=false`; enabling/tuning rate limits is a separate follow-up change.

## Proposed change

1. Capture a new verified systemd snapshot and archive current Caddy/PocketBase settings state.
2. Validate the versioned `server/deploy/Caddyfile` with the installed Caddy binary.
3. Reload Caddy with public deny responses for dashboard and management routes
   and an always-overwritten private `X-Zar-Client-IP` upstream header.
4. Install the versioned PocketBase migration that trusts only that private
   header and limits superuser requests to loopback (`127.0.0.1`, `::1`).
5. Restart PocketBase once so the migration is applied before it serves traffic.
6. Prove public management paths are denied, normal app paths retain their exact pre-change statuses, and direct loopback management routes remain reachable.

The public proxy returns a generic 404 for denied routes. Operator access is:

```text
ssh -L 18090:127.0.0.1:8090 zar-vps
http://127.0.0.1:18090/_/
```

No password, token, superuser record or customer row is read or recorded by this change.

## Preflight gates

- SSH `zaradmin` key login and sudo pass.
- Caddy and PocketBase are active; PocketBase `NRestarts=0`.
- Internal and both public health endpoints return 200.
- SQLite quick/integrity checks pass.
- New backup service run, checksum and immutable validation pass.
- Candidate Caddyfile validates and adapts without warnings/errors.
- The settings migration passes against an isolated copy of the production
  database; a temporary clone-only superuser proves a loopback token is allowed
  and the same token with a non-loopback private header is rejected.
- Pre-change allowed/denied HTTP matrix is recorded without credentials.

## Post-change gates

- Public dashboard, superuser route, settings, schema, logs, backups, crons and SQL routes return Caddy 404.
- Direct loopback dashboard remains 200; direct dummy superuser route remains the PocketBase invalid-credential status; direct management route remains PocketBase 401 without a token.
- Public health, user auth-methods and normal record routes retain pre-change status/body class.
- `trustedProxy.headers` contains only `X-Zar-Client-IP`, leftmost-IP mode is
  disabled, and `superuserIPs` contains only loopback values.
- A public request is recorded with its non-loopback client IP after the change;
  PocketBase no longer sees all Caddy traffic as `127.0.0.1`.
- Caddy config validates; Caddy/PocketBase/SSH remain active.
- PocketBase `NRestarts=0`, SQLite checks pass, domain counts/migrations are unchanged, and bounded journals contain no new errors.
- Direct external TCP 8090 remains closed/filtered.

## Rollback

1. Restore the archived Caddyfile and reload Caddy.
2. Stop PocketBase, revert the settings migration with `pocketbase migrate down 1`
   as `zarapp`, and remove the deployed migration only after history is clean.
3. Start PocketBase and verify the reverted settings.
4. Re-run health, allowed-route, SQLite, count, migration, restart and log checks.

If only Caddy validation fails, do not change settings or reload either service.

## Remaining risk after this change

- Built-in rate limiting remains disabled until a separate tested policy change.
- SSH and HTTP anomaly/failure alerts still have no external operator destination.
- A compromised regular user token remains governed by collection rules; this change does not fix open server-side invariant/concurrency/audit findings.
