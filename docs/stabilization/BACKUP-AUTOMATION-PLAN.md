# ZAR+ Local Backup Automation Change Plan

Status: executed successfully on 2026-10-30 under `TEMPORARY-RECOVERY-EXCEPTION.md`. Manual systemd run, isolated restore and the first natural timer-triggered run all passed. See `BACKUP-AUTOMATION-EVIDENCE-2026-10-30.md`.

## Objective

Replace the unaudited inline root cron command with an atomic, verified, restrictive and versioned daily SQLite backup job while preserving the explicit limitation that the scheduled copies still live on the same server.

This change improves local recovery quality. It does **not** satisfy the independent off-site backup gate.

## Verified starting state — 2026-10-30

- `/backups` is `0700 root:root` and the filesystem has approximately 21 GiB free.
- Daily databases are small (approximately 270 KiB) and currently created as `0644 root:root`.
- The cron command performs `.backup` but no integrity check, hash, atomic publish, lock, or failure alert.
- Its recursive retention expression matches every `/backups/zar-*.db`, including named containment and rollback artifacts after seven days.
- Read-only validation performed without immutable mode created `-wal`/`-shm` sidecars next to several stored backups.
- The encrypted off-server pre/post containment bundles remain the only independent copies, under the temporary pre-customer exception.

## Proposed change

1. Deploy versioned `server/tools/zar_backup.sh` as `/usr/local/sbin/zar-backup`, owned by root and mode `0750`.
2. Store scheduled files only in `/backups/zar-daily` (`0700 root:root`).
3. Use SQLite's read-only online backup API inside a hidden staging directory under a non-blocking process lock.
4. Verify the snapshot with immutable `quick_check`, `integrity_check` and required ZAR schema-table checks so validation creates no sidecars.
5. Build and flush the database, checksum and metadata together, then atomically publish their containing snapshot directory.
6. Retain 30 days and never fewer than seven successful, exact-name snapshot directories inside `zar-daily`; never traverse or delete named rollback artifacts in `/backups`.
7. Run from a hardened systemd oneshot with no network, a read-only source path, one writable destination, and only `CAP_DAC_READ_SEARCH` to read the `0600 zarapp` database.
8. Schedule daily at 03:00 UTC with a persistent timer and a two-minute random delay.
9. Disable the old cron only after a manual service run and restored-copy verification pass.
10. Restrict all pre-existing files directly under `/backups` to mode `0600`; do not delete legacy sidecars or rollback artifacts in this change.

## Test gates

- Shell syntax and systemd unit verification pass.
- Missing source or destination paths fail the service rather than silently skipping the scheduled job.
- Direct isolated run with overridden source/destination atomically creates exactly one snapshot directory containing database, checksum and metadata, all `0600`.
- `sha256sum -c`, immutable quick/integrity checks, record counts and migration history pass.
- Hardened systemd service exits successfully and records one `BACKUP_OK` journal line.
- Result contains no `-wal`, `-shm` or `.partial` file.
- A restore test using the newly scheduled-format database passes the repository recovery verifier.
- Timer is enabled and its next trigger is visible.
- PocketBase health, `NRestarts=0` and SSH administration remain healthy.

## Rollback

1. Disable and stop `zar-backup.timer` and `zar-backup.service`.
2. Restore the archived `/etc/cron.d/zar-backup` file.
3. Remove the installed unit/timer/script only after their hashes and copies are preserved.
4. Reload systemd and verify the cron daemon accepts the restored file.

Do not delete `/backups/zar-daily` during rollback; it contains valid recovery evidence. Do not change or delete named containment/service-hardening artifacts.

## Remaining limitations

- Same-host backups do not protect against server, disk, account or provider loss.
- No external alert destination exists yet; failures are visible in the systemd unit/timer and journal but are not pushed to an operator.
- The temporary exception expires before any customer/launch data or 2026-11-30, whichever comes first.
