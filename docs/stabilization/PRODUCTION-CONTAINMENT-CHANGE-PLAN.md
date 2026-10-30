# ZAR+ Production Containment Change Plan

Status: draft and rehearsal input only. This document does not authorize execution.

## Objective and scope

Apply exactly two reviewed, forward-only authorization migrations to production:

1. `1793260800_lock_workspace_deletion.js` — prevent anonymous and member deletion of workspaces.
2. `1793347200_lock_cash_entry_deletion.js` — prevent hard deletion of cash-journal history while preserving creation of reversal entries.

The change does not intentionally modify business rows, application binaries, Caddy, SSH, service ownership or Android clients. Those changes require separate reviewed plans.

The two recovered `179302*` email-template migrations are included in the repository so history is complete, but they are already recorded as applied in production and must not execute again.

## Expected artifact hashes

Verify these values from the reviewed release artifact before scheduling the change:

```text
694809da2509545844096a3c59b54fffdb80ec56759de3fd54cbcc8be6064ce3  1793260800_lock_workspace_deletion.js
d18818f2b0776007e6e6b83103740956db36e2b1f8636cb7a002ca62375ba09d  1793347200_lock_cash_entry_deletion.js
132388ee2db3fda91b518192d398065dcd469bb88d509ab4a99800062050c613  1793020980_updated_users.js
ebe4707098be1a55d4eb68b5ce2837a1931d5197f3fff5fad755c9f13d907a2c  1793023512_updated_users.js
```

Any mismatch is a stop condition. Do not normalize, rename, squash or edit an already-applied historical migration.

## Execution blockers

Do not start the maintenance window until all blockers are cleared:

- an encrypted recovery set has been copied off the production server and its checksum verified;
- the exact recovery set has passed `verify_recovery_set.py` on a separate machine;
- the owner has approved RPO, RTO, maximum downtime and a maintenance window;
- a named primary operator and rollback operator are present;
- a second key-authenticated, non-expiring SSH session is confirmed and kept open;
- current production binary, migration, configuration and database hashes have been compared with the baseline and all drift explained;
- disk space, certificate validity, system time and backup age are healthy;
- the release artifact and commands below have been reviewed by a second person;
- users have been notified that writes must stop during the window.

Pre-customer exception: the owner explicitly accepted the temporary lack of an independent cloud/second-media copy in `TEMPORARY-RECOVERY-EXCEPTION.md`. A fresh encrypted bundle on the owner's Windows computer was decrypted and verified, and the exact database passed the isolated restore gate. This exception permits only the two containment migrations and expires before customer data, launch, or 2026-11-30.

## Rehearsal evidence required

Before production, the release candidate must pass all of these on PocketBase `0.40.4`:

```text
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub test/zar_pocketbase_repository_test.dart
python server/tests/pocketbase_authz_test.py --pocketbase <verified-binary>
python server/tests/pocketbase_migration_lineage_test.py --pocketbase <verified-binary>
python server/tools/verify_recovery_set.py ...
```

Required results:

- workspace anonymous/member delete: `403`;
- cash update/delete: `403`;
- cash create and reversal create: `200`;
- service health: pass;
- source hash unchanged;
- SQLite integrity: `ok`;
- no missing or untracked JavaScript migrations;
- all eight domain-table counts and content hashes identical before/after.

## Pre-change capture

Run read-only checks first and attach their output to the evidence ledger. Use a unique UTC release identifier such as `zar-containment-YYYYMMDDTHHMMSSZ`.

```text
date -u +%FT%TZ
hostname
systemctl is-active zar-server.service
systemctl show zar-server.service -p MainPID -p ExecMainStartTimestamp -p NRestarts
/opt/zar/server/pocketbase --version
sha256sum /opt/zar/server/pocketbase
sha256sum /opt/zar/server/pb_migrations/*.js
sha256sum /etc/systemd/system/zar-server.service /etc/caddy/Caddyfile /etc/cron.d/zar-backup
sqlite3 -readonly /opt/zar/server/pb_data/data.db "PRAGMA quick_check; PRAGMA integrity_check; SELECT file FROM _migrations ORDER BY file;"
```

Capture only counts and hashes for business tables. Do not copy row contents into tickets, chat or logs.

## Fresh recovery set

The existing cron correctly uses SQLite `.backup`, but it stores only `data.db` on the same server. For this change, create a dedicated mode-`0700` staging directory and include:

- a fresh SQLite `.backup` of `data.db`;
- the complete `pb_migrations` directory;
- `zar-server.service`, `Caddyfile` and `zar-backup` cron configuration;
- a text manifest containing UTC time, sizes and SHA-256 values;
- the exact PocketBase version and official archive checksum;
- `pb_data/storage` if it exists at execution time.

Encrypt the archive before transfer, upload it to the approved off-site destination, then download or mount it on a separate verifier and run the restore runbook. Do not place encryption keys beside the backup or in shell history.

If the off-site upload, remote checksum or isolated restore fails, cancel the change.

## Maintenance execution

The commands must be rendered with the approved release identifier and staging path before review. Do not paste unresolved placeholders into a production shell.

1. Start the evidence ledger and record UTC time.
2. Stop application writes and confirm the maintenance window.
3. Stop PocketBase cleanly:

   ```text
   sudo systemctl stop zar-server.service
   sudo systemctl is-active zar-server.service
   ```

   Expected state: `inactive`. If the process remains active, stop and investigate; do not kill it blindly.

4. Create a second stopped-state SQLite backup and hash it. This is the immediate rollback database.
5. Copy the two new migration files from the verified release staging directory into `/opt/zar/server/pb_migrations/` with owner `root:root` and mode `0644`.
6. Re-run SHA-256 on all migration files and compare with the approved manifest.
7. Apply pending migrations once:

   ```text
   sudo /opt/zar/server/pocketbase migrate up \
     --dir=/opt/zar/server/pb_data \
     --migrationsDir=/opt/zar/server/pb_migrations
   ```

8. Before starting traffic, verify:

   ```text
   sqlite3 -readonly /opt/zar/server/pb_data/data.db "PRAGMA quick_check; PRAGMA integrity_check; SELECT file FROM _migrations WHERE file LIKE '1793%.js' ORDER BY file; SELECT name, updateRule, deleteRule FROM _collections WHERE name IN ('zar_workspaces','zar_cash_entries') ORDER BY name;"
   ```

   Expected rule state:

   - `zar_workspaces.deleteRule` is `NULL`;
   - `zar_cash_entries.updateRule` is `NULL`;
   - `zar_cash_entries.deleteRule` is `NULL`;
   - both new migration filenames appear exactly once.

9. Start PocketBase and validate:

   ```text
   sudo systemctl start zar-server.service
   sudo systemctl is-active zar-server.service
   curl --fail --silent --show-error https://app.titangold.ir/api/health
   curl --fail --silent --show-error https://zar.185-126-202-104.sslip.io/api/health
   sudo journalctl -u zar-server.service --since "10 minutes ago" --no-pager
   ```

10. Re-run counts and canonical content hashes. They must match the stopped-state pre-change evidence exactly.
11. Perform a normal existing-account sign-in and read-only smoke test from a controlled client. Do not test deletion against a real business record.
12. Keep enhanced monitoring active through the agreed observation window before closing the change.

## Immediate stop conditions

Stop and enter rollback if any of these occur:

- artifact or database checksum mismatch;
- an unexpected pending/applied migration;
- `quick_check` or `integrity_check` is not exactly `ok`;
- any business-table count or content hash changes;
- either delete rule is not `NULL`;
- PocketBase fails to start or health is not HTTP `200`;
- authentication or normal record reads fail;
- repeated process restarts, new 5xx errors or unexplained logs appear;
- the operator loses the safe administrative session.

## Rollback

Do not run `migrate down` on production. The security migrations intentionally do not reopen deletion in their down functions, and historical migration rewrites are not a reliable rollback mechanism.

Rollback is a full recovery-set restore:

1. Stop `zar-server.service` and confirm it is inactive.
2. Move the failed post-change `data.db`, any `-wal`/`-shm` sidecars and the two new migration files into a timestamped incident quarantine directory. Do not delete them.
3. Restore the stopped-state pre-change `data.db` and the exact pre-change migration directory from the verified recovery set.
4. Restore approved ownership and modes.
5. Run `quick_check`, `integrity_check`, migration-list and count/hash reconciliation while still stopped.
6. Start the service, verify both health endpoints, authentication and read-only business flows.
7. Preserve logs, manifests and the failed state for root-cause analysis.
8. Record the rollback decision and notify stakeholders. No second attempt occurs in the same window without a new review.

## Evidence ledger fields

Record all of the following without secrets or row contents:

- change/release identifier;
- operator and reviewer names;
- approved window, RPO/RTO and rollback deadline;
- Git commit and release artifact hashes;
- production baseline hashes before the change;
- off-site backup URI/identifier and remote checksum (not credentials);
- isolated restore report SHA-256 and result;
- stop/start UTC timestamps and measured downtime;
- migration output and final `_migrations` list;
- pre/post table counts and content hashes;
- health, authentication and log-check results;
- final go/rollback decision and approvers.
