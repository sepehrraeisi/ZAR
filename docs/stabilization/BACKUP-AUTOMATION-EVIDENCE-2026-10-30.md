# ZAR+ Local Backup Automation Evidence — 2026-10-30

Change identifier: `zar-backup-automation-20261030T200203Z`
First manual systemd run: 2026-10-30 20:02:52 UTC
Result: **PASS — verified local timer installed; independent/off-site recovery exception remains open**

## Why this is not the disaster-recovery exit gate

The scheduled snapshots are on the production server and therefore do not protect against loss of the server, disk, provider account or region. This change is a compensating control under `TEMPORARY-RECOVERY-EXCEPTION.md`; it does not authorize customer data or public launch.

## Pre-change defect

The legacy root cron command:

- produced mode `0644` database files;
- did not publish a checksum or metadata;
- did not perform quick/integrity/schema checks;
- had no concurrency lock or atomic multi-file publish;
- recursively deleted every `/backups/zar-*.db` older than seven days, including named rollback artifacts;
- left verification-created `-wal`/`-shm` sidecars next to historical backups.

`/backups` itself was `0700 root:root`, so the broad file modes were not directly traversable by unprivileged accounts. They were still normalized to `0600` in this change.

## Versioned artifacts

```text
server/tools/zar_backup.sh
sha256 57862e5053fc34b6a0aedf7c991c20e652c1d9529c933aee65caa0656c1398da

server/deploy/zar-backup.service
sha256 6f7b8f2e5764fec031931d95ebc6b444608429f54d3f1651a05fd3be6c503a4e

server/deploy/zar-backup.timer
sha256 29c7bced26b4140e05a34216208691fc2493b30d253fee523069d54422e996f4
```

Git forces LF line endings for migrations, shell scripts and systemd units through `.gitattributes`.

## Pre-deployment test gates

The candidate script ran only against disposable destinations before installation.

- Shell syntax: pass.
- Atomic snapshot directory containing `data.db`, `SHA256SUMS` and `METADATA`: pass.
- Directory/file modes `0700`/`0600`: pass.
- SHA-256 verification: pass.
- Immutable SQLite quick/integrity checks: `ok` / `ok`.
- Required ZAR schema tables: pass.
- Domain counts and migration history matched production: pass.
- WAL/SHM/partial artifacts: zero.
- Retention simulation: removed only three old exact-name snapshots, stopped at seven, and preserved a named rollback sentinel.
- Corrupt source simulation: nonzero exit and staging cleanup passed.
- Concurrent invocation: rejected by lock with nonzero exit.
- Disposable test data copies: deleted after validation.

An independent review stopped the first draft before deployment and caused these changes: fail instead of silently skipping missing paths, atomic directory publication, immutable destination validation, 30-day/minimum-seven retention, exact-name deletion scope, fixed PATH, 15-minute timeout and read-only source access.

## Installed behavior

- Script: `/usr/local/sbin/zar-backup`, `0750 root:root`.
- Service/timer: `/etc/systemd/system/zar-backup.{service,timer}`, `0644 root:root`.
- Destination: `/backups/zar-daily`, `0700 root:root`.
- Snapshot layout: `zar-YYYYMMDDTHHMMSSZ/{data.db,SHA256SUMS,METADATA}`.
- Snapshot files: `0600 root:root`.
- Source opened read-only using SQLite's online backup API.
- Snapshot validated before a single atomic directory rename.
- Retention: 30 days, never fewer than seven published snapshots, exact names and destination only.
- Service has no network, strict read/write paths, no privilege escalation and only `CAP_DAC_READ_SEARCH` to read the `0600 zarapp` source database.
- Systemd exposure: `2.7 OK`.
- Legacy cron was disabled only after the manual systemd backup passed; its original file is preserved in the root-owned change archive.
- Pre-existing files directly under `/backups` are now mode `0600`; no historical sidecar or rollback artifact was deleted.

## First installed snapshot

```text
/backups/zar-daily/zar-20261030T200252Z/data.db
sha256 1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8
```

- Service `Result=success`, `ExecMainStatus=0`.
- Journal contains `BACKUP_OK`; error journal has no entries.
- Checksum sidecar: pass.
- Immutable quick/integrity checks: `ok` / `ok`.
- Source/backup domain counts: exact match.
- Source/backup migration history: exact match.
- WAL/SHM/partial artifacts in `zar-daily`: zero.

The repository recovery verifier then restored this exact snapshot with PocketBase 0.40.4:

- status: `pass`;
- service health: `pass`;
- pending migrations: none;
- missing/untracked migrations: none;
- foreign-key violations: zero;
- all eight domain table counts and canonical content hashes reconciled;
- source hash unchanged and expected hash matched.

Machine-readable report:

```text
work/backup-recovery-20261030T200203Z/daily-restore-report.json
```

The transient unencrypted local snapshot/tar used for this restore test was deleted after the report was written. The previously created encrypted full recovery bundle remains the off-server recovery copy.

## Timer and rollback evidence

```text
timer: enabled and active
next trigger at capture: 2026-10-31 03:00:52 UTC
schedule: daily 03:00 UTC with up to two minutes randomized delay
```

Root change archive:

```text
/root/zar-backup-automation-20261030T200203Z
```

Off-server evidence archive:

```text
work/backup-recovery-20261030T200203Z/zar-backup-automation-20261030T200203Z-evidence.tar
sha256 b1b501580d627f90dbc2599d24ca825735fa6f14e5626fcb08f9207b4ffd95ca
```

PocketBase stayed active with `NRestarts=0`; no application maintenance window was required.

## Natural timer confirmation — 2026-10-31

The first scheduled run started at `03:01:02 UTC` and completed with
`BACKUP_OK`:

```text
/backups/zar-daily/zar-20261031T030102Z/data.db
sha256 1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8
```

A fresh manual recovery gate before the administrative-access change also
passed at `08:48:03 UTC` as
`/backups/zar-daily/zar-20261031T084803Z/data.db`, with the same SHA-256 and
successful checksum/immutable quick/integrity checks.

## Remaining gates

- Add backup-age/failure alerting when an operator notification channel exists.
- Move encrypted recovery to an independent destination and run a second-operator restore before customer/launch data or 2026-11-30.
- Approve RPO, RTO, retention, jurisdiction and recovery-key custody.
