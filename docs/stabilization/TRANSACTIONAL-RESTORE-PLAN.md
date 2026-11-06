# ZAR+ Transactional Cloud Restore Plan

Status: local implementation, destructive tests, two operational security-review remediation rounds, independent closure audits, the final fresh current-production clone rehearsal and exact code/evidence checkpoint CI are green. Draft PR #3 remains unmerged and production deployment has not occurred.

Last updated: 2026-11-05 (Asia/Tehran)

## Objective and boundary

The change replaces the unsafe client GET-then-batch restore path with a
server-side compare-and-swap transaction. A successful commit must replace all
seven domain collections, including the append-only cash journal, and create
its idempotency receipt in one PocketBase transaction. Failure must leave both
the domain state and receipts unchanged.

This plan does not authorize a production deployment. The production server
currently has the reviewed cash update/delete lock and exactly 11 enabled rate
rules. The branch also has a fail-closed client guard, but its presence in the
installed Android APK is not proven. The candidate migration, hooks, 13-rule
state and explicit service unit exist only locally until every gate below
passes and a separate change decision is recorded.

The temporary same-host backup exception remains in force. There are no
customers or approved real customer datasets, and no independent server is
available. That exception permits stabilization work to continue; it does not
make same-host snapshots disaster recovery and it expires before customer
data, launch or 2026-11-30.

## Candidate artifacts

- `server/pb_migrations/1793604800_transactional_restore.js`
- `server/pb_hooks/zar_restore.js`
- `server/pb_hooks/zar_restore_routes.pb.js`
- `server/deploy/zar-server-transactional-restore.conf`
- `server/scripts/guarded_transactional_restore_{deploy,rollback,contain}.sh`
- `server/scripts/test_guarded_transactional_restore_clone.sh`
- `server/scripts/transactional_restore_{state,state_guard,canary}.py`
- `server/scripts/transactional_restore_expected_state.json`
- `server/tests/pocketbase_transactional_restore_test.py`
- the migration-lineage, authorization and Flutter restore tests in this branch

Before a rehearsal, create a manifest containing the reviewed Git commit,
byte size, owner/mode and SHA-256 of every artifact. PocketBase must remain
version `0.40.4` with the already verified binary checksum; a version change is
a different workstream. The final `0004` rehearsal pinned expected-state
manifest SHA-256
`3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3`
and canary SHA-256
`8e17b0973846da01c158f2960e9709594a1b3742fb39cf27b29a458d75c0f697`.

## Security and correctness contract

The candidate is acceptable only if all of these properties are proven:

1. Anonymous requests are rejected and the authenticated user is resolved
   again inside the transaction.
2. Commit requires password re-authentication; a bearer token alone cannot
   erase the cash journal.
3. The authenticated user belongs to exactly one selected workspace and an
   existing workspace membership list cannot be changed through Record API.
4. The client supplies the expected state hash and the server rechecks it in
   the same transaction; stale state returns conflict without mutation.
5. The request ID is unpredictable and idempotent. Repeating the identical
   request returns the original private receipt. Reusing it for different
   content is rejected without mutation.
6. All seven collections and the receipt commit or roll back together.
7. Snapshot IDs, business/workspace identity, references and accounting
   invariants are validated on the server; client validation is defense in
   depth, not the trust boundary.
8. Receipt Record API rules remain private. A receipt contains hashes,
   counts, actor/workspace and timestamps, not the financial snapshot.
9. Body size, collection/total record caps, canonicalization depth and request
   rate are bounded. The candidate expected rate state is exactly 13 rules.
10. Normal cash create/reversal behavior remains available while normal cash
    update/delete stays denied.

## Clone rehearsal

Use two disposable targets: a fresh database for destructive boundary tests
and a byte-for-byte copy of the newest verified production snapshot for
migration/reconciliation. Neither may bind publicly or reuse production
credentials. Run the clone as `zarapp` with the production systemd sandbox, a
different loopback port, root-owned read-only migrations/hooks and
`--hooksWatch=false`.

Capture before and after evidence for:

- source database hash; both databases' `quick_check` and `integrity_check`;
- migration history and migration artifact hashes;
- domain table counts and canonical content hashes;
- complete settings hash and exact ordered rate rules (`11` before, `13`
  after candidate migration);
- receipt count and canonical receipt metadata hash, with no payload values;
- unit verification, service user, listener, `NRestarts`, health and bounded
  journal output.

The fresh-database matrix must prove at least:

- anonymous state/commit `401`; authenticated state success;
- wrong password rejected; correct password accepted;
- shared workspace and attempted membership takeover rejected;
- stale expected hash `409` and concurrent record survival;
- valid seven-collection restore including cash, then cash update/delete `403`;
- identical replay after a real service restart returns the same receipt;
- request-ID reuse with changed snapshot is rejected;
- cross-workspace/case-insensitive ID collision and invalid references or
  accounting data roll back completely;
- private receipt Record API returns `403`;
- body/record/depth boundaries and practical maximum dataset complete within
  the agreed maintenance budget;
- commit rate boundary, retry behavior, NAT/shared-IP behavior and natural
  reset pass on the clone. Do not intentionally exhaust production limits.

Run all three real PocketBase tests against the verified binary:

```text
python server/tests/pocketbase_authz_test.py --pocketbase <verified-binary>
python server/tests/pocketbase_migration_lineage_test.py --pocketbase <verified-binary>
python server/tests/pocketbase_transactional_restore_test.py --pocketbase <verified-binary>
```

Then run the full Flutter analyzer/test suite and require the exact candidate
head to pass Draft PR CI. Draft PR #3 remains unmerged without an explicit
owner decision.

## Production change sequence (not yet authorized)

The eventual change window must name the operator and rollback owner, pin the
exact commit/manifest, and prewrite all commands. The safe order is:

1. Confirm no customer/real financial data and re-confirm the temporary
   recovery exception is still valid.
2. Create a fresh atomic snapshot and recovery set; verify checksums,
   migrations, counts, schema and both SQLite databases. Copy the evidence
   bundle off the server to the already protected owner workstation.
3. Re-run the exact candidate against a clone of that snapshot and compare the
   result with the approved manifest.
4. Record production baseline: current latest migration, exact 11 rules,
   receipt collection absence, counts/hashes, health, listener, restarts and
   journal boundary.
5. Stop `zar-server`; prove it is inactive and port 8090 is no longer listening.
6. Install only the reviewed migration as `root:root 0644`; do not copy hooks
   yet.
7. Run explicit `migrate up` with production `--dir` and `--migrationsDir`.
   Verify the exact history delta, schema, immutable membership rule, private
   receipt collection, exact 13 rules, counts and integrity while stopped.
8. Install both reviewed hook files as `root:root 0644` under a root-owned
   `0755` directory. Install the reviewed unit with explicit data, migration
   and hook paths and `--hooksWatch=false`; run `systemd-analyze verify` and
   `daemon-reload`.
9. Start the service. Require health, normal member authentication, low-rate
   state-route smoke, public admin denial, listener, counts/integrity,
   `NRestarts=0` and clean bounded logs. Do not perform a destructive restore
   against production merely as a smoke test.
10. Observe at defined minute 0/5/15 checkpoints and publish sanitized evidence.

Any unexplained difference stops the window. Never repair domain rows manually.

## Rollback and containment

The existing guarded rate-limit rollback script is not a rollback mechanism
for this change: after the candidate migration becomes latest, its exact guard
must refuse. Do not bypass that protection.

Before the first receipt exists, an immediate down migration is permitted only
if the service is stopped, the candidate is still exactly the latest history
row, all hashes/settings/counts match the approved states, receipt count is
zero, and this exact path has passed on the production clone. Remove/disable
the route hooks while stopped, run guarded `migrate down 1`, prove `13` rules
returned exactly to `11`, verify history/schema/counts/integrity, restore the
prior unit, then start and verify health. A dedicated script and evidence set
must be reviewed before this option is used.

After any receipt exists, or when commit outcome is ambiguous, **do not run
down**. The migration is designed to refuse because down would destroy
idempotency/audit evidence. Stop the service, remove or disable only the route
hook, retain the helper, migration, receipt collection and 13-rule settings,
restart with normal cash deletion still denied; a new client sees the missing
route and fails closed. Then deliver a forward-only fix. Preserve both
databases and the complete incident evidence.

Rehearse failpoints after migration installation, after migrate-up, with a
missing/corrupt helper hook and with unhealthy start. Every recovery branch
must restore a known state without deleting receipts.

### Completed current-production rehearsal

On 2026-11-05, the final `0004` run used root-owned guarded tools against fresh
SQLite backup copies of the current production state under
`zar-restore-clone-20261105-0004.service` on loopback port `18093`. Six ordered
deployment failpoints, successful deploy, pre-receipt rollback, rollback
failures before stop/during recovery/after start, containment failures before
stop and after start, zero-receipt ambiguous containment, real
commit/restart/replay, receipt-bearing deploy recovery, wrapper/raw-down refusal
after a receipt and receipt-present containment all passed. Invalid or
unavailable state proof always left the service/listener stopped; validated
receipt state restarted only after route quarantine.

The harness also rejected failure-file symlinks and writable evidence parents
at all three entry points, rejected an untrusted privileged input without
restarting the clone, bound the canary to one real disposable tree and rejected
same-name/cross-name production database hardlinks. Two operational
security-review remediation rounds and independent closure audits reported no
remaining blocker before this run. The exact rate-policy transition was
`11`→`13`; production pre/post sanitized state hashes were both
`de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`,
and all candidate production paths stayed absent. The retained remote evidence
is `/root/zar-transactional-restore-clone-20261105-0004`; its sanitized local
archive contains `365` entries and has SHA-256
`a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`.
See `TRANSACTIONAL-RESTORE-CLONE-EVIDENCE-2026-11-05.md`.

The final local verification ran `24` deterministic
state/guard/manifest/canary tests (`22` passed and two were expected platform
skips), the real
PocketBase commit → restart → replay test, shell/Python syntax and whitespace
checks, and the full PocketBase authorization, migration-lineage and
transactional-restore suites. All passed on the same candidate content.

## Recovery and retention

Once deployed, recovery sets must include the exact `pb_hooks` directory and
its manifest in addition to data, migrations, binary and service/proxy/backup
configuration. The recovery verifier now reconciles receipt count and a
canonical metadata hash without exposing snapshot or personal data, hashes the
hook manifest and restarts with hot reload disabled. A local historical
production-derived snapshot passed these checks on 2026-11-03. The fresh
current-production clone then proved receipt replay after a real service restart
and the exact `11`→`13` rate-rule delta on 2026-11-05.

Receipts are audit/idempotency evidence. No deletion or retention job is
authorized yet. Before launch, define legal/business retention, an append-only
or archived evidence strategy and a forward-only purge procedure, then test it
against a recovery clone.

## Deployment gate

Local server-side accounting validation, real PocketBase tests, Flutter checks,
receipt/hook-aware recovery verification, dedicated guarded deployment tooling
and the fresh current-production clone rehearsal are green. GitHub Actions run
#261 passed both jobs at exact code/evidence checkpoint `e9ee6e0`. Production
deployment remains blocked until the owner records a separate explicit
change-window decision with a fresh recovery set and named operator/rollback
owner, and any later deployment head retains green CI. The operational security-review
and clone/tooling gates are closed for the reviewed local bytes; passing these
non-production gates does not change production status.
