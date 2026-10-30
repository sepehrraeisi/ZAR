# ZAR+ PocketBase Service Hardening Change Plan

Status: prepared; canary and production evidence must be appended after execution.

## Objective

Remove root execution, close direct port `8090` exposure, make application code read-only to the process, and restrict writes to `pb_data` without changing public URLs or application data.

## Verified starting state — 2026-10-30

- Ubuntu 24.04, systemd 255.
- Unit: `/etc/systemd/system/zar-server.service`.
- Process: root/root.
- Command: `/opt/zar/server/pocketbase serve --http=0.0.0.0:8090`.
- `pb_data` and databases: root-owned, directory `0755`, files `0644`.
- Port `8090`: listening on all interfaces.
- Caddy already proxies both public hostnames to `127.0.0.1:8090`.
- PocketBase `NRestarts=0`; health endpoints pass.
- `systemd-analyze security`: `9.6 UNSAFE`.

## Preconditions and stop conditions

Proceed only if:

1. SSH via `zaradmin` and non-interactive sudo pass.
2. PocketBase is active with `NRestarts=0`.
3. Database quick/integrity checks pass.
4. Internal and public health endpoints pass.
5. A stopped-state SQLite backup and unit/config archive are created and verified.
6. A canary instance using a recovery copy passes under the proposed sandbox.

Stop or roll back if the process does not remain active, migrations differ, data counts change, SQLite checks fail, Caddy health fails, port `8090` remains externally reachable, or logs contain a new service error.

## Proposed change

1. Create system account `zarapp` with no login shell and a locked password.
2. Keep binary, migrations and application directory root-owned and read-only to `zarapp`.
3. Change only `pb_data` recursively to `zarapp:zarapp`; directory mode `0700`, regular data files `0600`.
4. Add a systemd drop-in that:
   - runs as `zarapp:zarapp`;
   - binds PocketBase to `127.0.0.1:8090`;
   - sets `UMask=0077`;
   - permits writes only to `/opt/zar/server/pb_data`;
   - removes Linux capabilities and privilege escalation;
   - isolates home, devices, temporary files, kernel/control-group surfaces and namespaces;
   - limits address families to Unix/IPv4/IPv6 sockets.
5. Reload systemd and restart once during a measured maintenance interval.

No database migration, schema change, PocketBase upgrade, Caddy change, firewall change or backup-retention change is part of this change.

## Rollback

Keep the original unit and a recursive ownership/mode manifest in the change archive. If validation fails:

1. Stop `zar-server.service`.
2. Remove the hardening drop-in.
3. Restore original ownership/modes and, if needed, the stopped-state database.
4. Run `systemctl daemon-reload` and start the original unit.
5. Re-run SQLite, migration, record-count, internal/public health, restart and log gates.

Do not delete `zarapp` during an incident; account cleanup is not needed to restore service.

## Required evidence

- Pre/post process UID/GID, effective `ExecStart`, bind address and file modes.
- Canary unit properties, health result and logs.
- Archive/backup paths and SHA-256 values.
- Exact downtime timestamps.
- SQLite quick/integrity checks before and after.
- Domain record counts before and after.
- Migration list before and after.
- Internal and both public health endpoints.
- External `8090` timeout/refusal.
- `systemd-analyze security` before and after.
- `NRestarts` and bounded service logs.
