# ZAR+ PocketBase Restore and Reconciliation Runbook

Status: exercised locally against a production backup copy on 2026-10-30; production recovery and off-site storage remain pending.

## Purpose

This runbook proves that a ZAR+ PocketBase recovery set can be restored in isolation, upgraded through the repository migrations, started successfully, and reconciled without changing domain data. It is a mandatory gate before any production migration, service hardening or application release.

The verifier is intentionally non-destructive:

- it opens the supplied source database read-only;
- it rejects a non-empty WAL sidecar because a lone `data.db` would not be a complete copy;
- it copies the database and migrations to a disposable directory;
- it binds the restored service only to `127.0.0.1` on an ephemeral port;
- it never prints row payloads, member lists, names, phones, notes or tokens;
- it proves the source SHA-256 is unchanged when the run finishes.

## Recovery set

A complete recoverable release must contain or identify all of the following:

1. A consistent SQLite backup created with PocketBase backup support or SQLite `.backup`, not a raw copy of a live WAL database.
2. Every applied JavaScript migration with its original filename and bytes, plus reviewed pending migrations.
3. The exact PocketBase version and verified release checksum.
4. Versioned systemd, reverse-proxy and backup configuration.
5. Any `pb_data/storage` objects if file fields are introduced later.
6. Secrets, SMTP credentials and private keys in a separately encrypted secret store; never in Git or the evidence report.
7. A manifest containing UTC capture time, file size and SHA-256 for every recovery artifact.

`auxiliary.db` contains operational logs and is useful for incident investigation, but it is not required to reconstruct the business records in `data.db`. Preserve it separately when incident evidence matters.

## Required tools

- PocketBase `0.40.4` matching the deployed major/minor version.
- Python 3 with the standard library.
- The repository migration directory `server/pb_migrations`.
- `server/tools/verify_recovery_set.py`.

For the official Linux amd64 PocketBase `0.40.4` archive, the verified SHA-256 recorded during this audit is:

```text
9042ec818570e79c3628dadcd0a756c1496d9e1173918ec409d133c02f82e5fa
```

Always re-verify the downloaded archive before extracting or running it.

## Isolated verification procedure

### 1. Quarantine the source artifacts

Copy the backup, migrations and sanitized operational configuration into a non-repository `work/` directory. Keep the database out of Git and user-facing outputs. Record hashes before reading or transforming migration files.

Stop immediately if:

- the expected database hash differs;
- an applied `.js` migration is absent from the repository;
- a recovered historical migration differs from its production hash;
- a non-empty `data.db-wal` exists without the matching database snapshot;
- the input is the live production path rather than a backup copy.

### 2. Run the recovery verifier

Example from the repository root:

```text
python server/tools/verify_recovery_set.py \
  --pocketbase <verified-pocketbase-binary> \
  --database <quarantined-data.db> \
  --migrations server/pb_migrations \
  --expected-database-sha256 <captured-sha256> \
  --report <work-evidence-directory>/restore-report.json
```

The JSON report is evidence, not a backup. It contains only hashes, counts, migration filenames and pass/fail diagnostics.

### 3. Apply the pass/fail gate

The restore gate passes only when all of the following are true:

- top-level `status` is `pass` and `failures` is empty;
- expected source SHA-256 matches and `hash_unchanged` is `true`;
- source and restored `quick_check` and `integrity_check` return only `ok`;
- `foreign_key_violations` is zero;
- `domain_errors` is empty before and after restore;
- `untracked_applied_before` and `missing_after_restore` are empty;
- restored PocketBase health is `pass`;
- every domain table in `record_reconciliation` is `true`;
- record counts and canonical content SHA-256 match before and after migration.

The current structural domain checks cover:

- valid JSON payloads and member arrays;
- outer record ID versus payload ID consistency;
- every record belonging to an existing workspace;
- person, deal, settlement, allocation, reversal and coin-type references;
- prevention of cross-workspace references in the recovered dataset.

This verifier does not replace the Dart domain validation suite. Exact accounting calculations, allocation ceilings, reversal amounts and state-transition rules remain covered by application tests and require server-side enforcement in later phases.

### 4. Exercise supported migration lineages

Run both disposable PocketBase integration tests:

```text
python server/tests/pocketbase_authz_test.py --pocketbase <verified-pocketbase-binary>
python server/tests/pocketbase_migration_lineage_test.py --pocketbase <verified-pocketbase-binary>
```

The lineage test must pass for:

- a fresh install with every migration in timestamp order;
- an older developer/staging database that already applied the workspace lock before the two recovered email-template migrations appeared;
- a production clone where the email-template migrations are already applied and only reviewed forward migrations remain pending.

Never run `migrate down` against production migration history. Correct a deployed migration with a new forward-only migration or restore the entire verified recovery set.

## Evidence from the 2026-10-30 drill

Source: the server-created SQLite `.backup` file `/backups/zar-2026-10-30.db`, copied read-only into local quarantine.

- Source SHA-256: `a0da2edc42d46ddff0737ccaa4e40be7f5b141b3be92188c7cbae00828948907`
- Source and restored SQLite checks: `ok`
- Source hash unchanged: yes
- Restored health endpoint: pass
- Applied during isolated restore: `1793260800_lock_workspace_deletion.js` and `1793347200_lock_cash_entry_deletion.js`
- Untracked applied JavaScript migrations: none after recovering the two production template migrations
- Missing migrations after restore: none
- Domain reconciliation: all eight tables matched exactly
- Record counts: workspaces `1`, people `1`, settlements `1`; deals, coin types, currency types, allocations and cash entries `0`
- Domain-reference errors: none
- Fresh-install lineage: pass
- Existing-developer lineage: pass

The detailed machine-readable evidence is intentionally retained under the local `work/recovery-evidence-20261030/` directory and is not committed because it refers to a production-derived recovery exercise.

## Production recovery or deployment gate

Before changing production:

1. Schedule a maintenance window and name an operator and rollback owner.
2. Confirm business-approved RPO, RTO and maximum downtime; these are not yet defined.
3. Create a fresh full recovery set and copy an encrypted copy off the server.
4. Re-run this isolated verifier against that exact set.
5. Write the intended migration, validation and rollback commands before execution.
6. Keep a verified SSH session open and do not combine database, SSH, service-user and proxy hardening in one change.
7. Apply one reviewed forward migration.
8. Verify service health, authentication, authorization regression tests and business record counts.
9. Stop immediately on any unexplained difference; restore the entire verified set rather than editing records manually.
10. Record UTC timestamps, operators, hashes, commands, outcomes and the final decision in the handoff ledger.

## Remaining disaster-recovery gaps

- Backups are still stored only on the production server and retained for seven days.
- Encryption, off-site replication, automated age monitoring and restore alerts are not implemented.
- RPO, RTO, legal retention and data-residency requirements need owner decisions.
- A second operator has not yet repeated the drill.
- Recovery of the Android signing key and installed APK has not been verified.
- File-storage recovery must be added if future PocketBase collections introduce uploaded files.

Until those gaps are closed, this drill proves local recoverability of the captured database set; it does not yet satisfy full disaster recovery.
