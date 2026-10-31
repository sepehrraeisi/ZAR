# ZAR+ PocketBase Administrative Access Containment Plan

Status: completed in production on 2026-10-31; all gates passed and rollback was
not required. See `ADMIN-ACCESS-CONTAINMENT-EVIDENCE-2026-10-31.md`.

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
- superuser auth/records by either collection name or PocketBase's fixed system
  collection ID: `/api/collections/_superusers/...` and
  `/api/collections/pbc_3142635823/...`;
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
- PocketBase `NRestarts=0`, SQLite checks pass, domain counts are unchanged,
  migration history gains exactly `1793394000_trust_caddy_client_ip.js`, and
  bounded journals contain no new errors.
- Direct external TCP 8090 remains closed/filtered.

## Rollback

1. Keep the filtering Caddy configuration active while settings are reverted.
2. Stop PocketBase and refuse automatic rollback unless this remains the latest
   applied migration and the three settings still equal the deployed expected
   values. Revert it with `pocketbase migrate down 1` as `zarapp`, passing the
   explicit production `--dir` and `--migrationsDir` paths, and remove the
   deployed migration only after history is clean. Its down body deliberately
   restores the captured empty/false baseline and must not overwrite an
   intervening operator edit.
3. While PocketBase remains stopped, restore the archived Caddyfile, validate it
   and reload Caddy.
4. Start PocketBase and verify the reverted settings and public health.
5. Re-run health, allowed-route, SQLite, count, migration, restart and log checks.

Exact guarded rollback for this production change only (it intentionally
restores the original public Caddy behavior and therefore is an emergency full
rollback, not the preferred settings-only rollback):

```bash
sudo -n bash <<'ROLLBACK'
set -Eeuo pipefail

readonly evidence=/root/zar-admin-access-20261031T084900Z
readonly migration=1793394000_trust_caddy_client_ip.js
readonly migration_path=/opt/zar/server/pb_migrations/$migration
readonly expected_settings='["X-Zar-Client-IP"]|0|["127.0.0.1","::1"]'
readonly baseline_settings='[]|0|[]'
stopped=0

settings_value() {
  sqlite3 -readonly /opt/zar/server/pb_data/data.db \
    "SELECT json_extract(value, '$.trustedProxy.headers') || '|' ||
            json_extract(value, '$.trustedProxy.useLeftmostIP') || '|' ||
            json_extract(value, '$.superuserIPs')
       FROM _params WHERE id='settings';"
}

latest_migration() {
  sqlite3 -readonly /opt/zar/server/pb_data/data.db \
    "SELECT file FROM _migrations ORDER BY applied DESC, file DESC LIMIT 1;"
}

migration_count() {
  sqlite3 -readonly /opt/zar/server/pb_data/data.db \
    "SELECT count(*) FROM _migrations WHERE file='$migration';"
}

restart_on_error() {
  rc=$?
  trap - ERR
  if [ "$stopped" = 1 ]; then
    systemctl start zar-server || true
  fi
  echo "ROLLBACK_STOPPED rc=$rc; filtering Caddy remains loaded; inspect before continuing" >&2
  exit "$rc"
}
trap restart_on_error ERR

# Refuse drift before the maintenance window.
test "$(sha256sum /etc/caddy/Caddyfile | awk '{print $1}')" = \
  4586188b7917619a54e3c48c8aad14751ed4807118a78f33ae7a0d84b9bced65
test "$(sha256sum "$evidence/Caddyfile.before" | awk '{print $1}')" = \
  694597fc2cd0c259740ffb5df68d92e581dce5637790e2393bc9ad3c210dc4c4
test "$(migration_count)" = 1
test "$(latest_migration)" = "$migration"
test "$(settings_value)" = "$expected_settings"

systemctl stop zar-server
stopped=1

# Recheck after traffic is stopped; never overwrite an intervening edit.
test "$(migration_count)" = 1
test "$(latest_migration)" = "$migration"
test "$(settings_value)" = "$expected_settings"

printf 'y\n' | runuser -u zarapp -- /opt/zar/server/pocketbase migrate down 1 \
  --dir=/opt/zar/server/pb_data \
  --migrationsDir=/opt/zar/server/pb_migrations
test "$(migration_count)" = 0
test "$(settings_value)" = "$baseline_settings"
rm -f -- "$migration_path"

# PocketBase remains stopped until the original Caddyfile is validated/loaded.
install -o root -g root -m 0644 "$evidence/Caddyfile.before" /etc/caddy/Caddyfile
/usr/local/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl reload caddy
systemctl start zar-server
stopped=0

curl -fsS http://127.0.0.1:8090/api/health >/dev/null
curl -fsS https://app.titangold.ir/api/health >/dev/null
test "$(settings_value)" = "$baseline_settings"
test "$(sqlite3 -readonly /opt/zar/server/pb_data/data.db 'PRAGMA integrity_check;')" = ok
systemctl is-active --quiet caddy
systemctl is-active --quiet zar-server
echo ROLLBACK_PASS
ROLLBACK
```

The clone migration down/up path was exercised. The production rollback above
was prepared and armed during deployment but was not executed because every
post-change gate passed.

If only Caddy validation fails, do not change settings or reload either service.

## Remaining risk after this change

- Built-in rate limiting remains disabled until a separate tested policy change.
- SSH and HTTP anomaly/failure alerts still have no external operator destination.
- A compromised regular user token remains governed by collection rules; this change does not fix open server-side invariant/concurrency/audit findings.
