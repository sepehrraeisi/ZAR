# ZAR+ Stabilization Handoff

Last updated: 2026-11-06 (Asia/Tehran)
Status: **IN PROGRESS — production containment remains stable; transactional cloud restore, guarded tooling, the final fresh 11→13 production-clone rehearsal and exact-head GitHub CI are green after two security-review remediation rounds and independent closure audits. PR #3 was merged into `master` (merge commit `725c8fa`) on 2026-11-06 with explicit owner approval; the transactional restore candidate remains NOT deployed to production and still requires a separate explicit owner decision (planned after roadmap Phase 1).**
Change freeze: no feature work; every production mutation must continue through the backup/restore and rollback gates below.

## 0. Post-handoff action log

- 2026-11-06 — Owner approved merging PR #3. Independently verified branch tip == PR head (`2ebd9d88`) and all check-runs `success` before merging. Merged `--no-ff` as `725c8fa`, pushed to `master`; tag `stabilization-baseline` pushed (on `2ebd9d8`). Local CI reproduced on merged `master`: `flutter analyze --no-fatal-infos` clean, `flutter test` 345/345 pass. Branch protection enabled on `master`: required checks `flutter-checks` + `pocketbase-authorization` (strict), enforce_admins on, force-push/deletion off, PRs required with 0 approvals. Owner decisions recorded: transactional restore deploys after roadmap Phase 1 in a dedicated maintenance window; public signup stays closed until launch. Execution roadmap: `docs/stabilization/ROADMAP-2026-11.md`.

## 1. Objective

Stabilize ZAR+ before further product development: establish a reproducible source-of-truth, prevent data loss and unauthorized access, characterize current behavior, close critical security risks, verify accounting/operational invariants, complete operational documentation, and produce auditable release gates.

The defensible completion statement is not “there are no bugs.” It is: all known critical risks and critical user journeys are covered by evidence, tests, recovery drills, and explicit acceptance gates.

## 2. Authoritative locations

### GitHub

- Repository: `https://github.com/sepehrraeisi/ZAR`
- Draft stabilization PR: `https://github.com/sepehrraeisi/ZAR/pull/3` — **merged into `master` on 2026-11-06 (merge commit `725c8fa`)**
- Default branch: `master`
- Baseline commit: `e60d68dda3c1876dc5af99e36c1f455b76fd8a50`
- Baseline commit is unsigned.
- `master` branch protection (enabled 2026-11-06): required checks `flutter-checks`, `pocketbase-authorization` (strict), enforce_admins, no force-push/deletion, PRs required (0 approvals).
- Open pull requests/issues/releases at baseline: none.
- Existing remote branch: `codex/phase-a2-ux` at `b45e1ff810ade8e2ca28308b7bbe9592ce6e3ad0`.

### Local working copy

- Clone: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\ZAR`
- Current local branch: `codex/stabilization-baseline`
- Programmer handoff (single entry point): `docs/stabilization/PROGRAMMER-HANDOFF.md`
- Handoff (canonical): `docs/stabilization/HANDOFF.md`
- Baseline evidence manifest: `docs/stabilization/BASELINE.md`
- Findings register: `docs/stabilization/FINDINGS.md`
- Restore/reconciliation runbook: `docs/stabilization/RESTORE-RUNBOOK.md`
- Transactional cloud-restore plan: `docs/stabilization/TRANSACTIONAL-RESTORE-PLAN.md`
- Transactional current-production clone evidence: `docs/stabilization/TRANSACTIONAL-RESTORE-CLONE-EVIDENCE-2026-11-05.md`
- Production containment change plan: `docs/stabilization/PRODUCTION-CONTAINMENT-CHANGE-PLAN.md`
- Production containment evidence: `docs/stabilization/PRODUCTION-CONTAINMENT-EVIDENCE-2026-10-30.md`
- SSH hardening plan: `docs/stabilization/SSH-HARDENING-PLAN.md`
- SSH hardening evidence: `docs/stabilization/SSH-HARDENING-EVIDENCE-2026-10-30.md`
- PocketBase service hardening plan: `docs/stabilization/POCKETBASE-SERVICE-HARDENING-PLAN.md`
- PocketBase service hardening evidence: `docs/stabilization/POCKETBASE-SERVICE-HARDENING-EVIDENCE-2026-10-30.md`
- Local backup automation plan: `docs/stabilization/BACKUP-AUTOMATION-PLAN.md`
- Local backup automation evidence: `docs/stabilization/BACKUP-AUTOMATION-EVIDENCE-2026-10-30.md`
- Administrative access plan: `docs/stabilization/ADMIN-ACCESS-CONTAINMENT-PLAN.md`
- Administrative access evidence: `docs/stabilization/ADMIN-ACCESS-CONTAINMENT-EVIDENCE-2026-10-31.md`
- Rate-limiting plan: `docs/stabilization/RATE-LIMITING-PLAN.md`
- Rate-limiting canary evidence: `docs/stabilization/RATE-LIMITING-EVIDENCE-2026-10-31.md`
- Rate-limiting production evidence: `docs/stabilization/RATE-LIMITING-PRODUCTION-EVIDENCE-2026-11-01.md`
- Temporary pre-customer recovery exception: `docs/stabilization/TEMPORARY-RECOVERY-EXCEPTION.md`
- Recovery verifier: `server/tools/verify_recovery_set.py`
- Local machine-readable recovery evidence: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\recovery-evidence-20261030\restore-report.json`
- Sanitized server audit notes: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\server-review-notes.md`
- Off-server administrative evidence archive: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\admin-access-20261031T084900Z\zar-admin-access-20261031T084900Z-evidence.tar`
- Off-server rate-limit canary/deploy/rollback archive: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-canary-20261031\zar-rate-limit-evidence-complete-v6-20261031.tar` (SHA-256 `6a198f258744202c30402c965a7515d787ef38ff1a6a7927016acabf2244bdd0`)
- Off-server rate-limit production archive: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-production-20261101\zar-rate-limit-production-evidence-20261101.tar` (81 entries; internal hashes passed; SHA-256 `7877588bbee36233c854fa45b7dfa761eb7252179f4166d1313b7efc697adc95`)
- Sanitized transactional-restore clone archive: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\transactional-restore-clone-20261105-0004\zar-transactional-restore-clone-20261105-0004.tar.gz` (365 archive entries; no symlink, unsafe path, database or private state; SHA-256 `a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`)
- User-facing handoff mirror: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\outputs\ZAR-STABILIZATION-HANDOFF.md`
- Programmer-handoff mirror: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\outputs\ZAR-PROGRAMMER-HANDOFF.md`

### Production server

- SSH alias: `zar-vps`
- Host: `185.126.202.104`
- SSH user used for operations: `zaradmin` with non-interactive sudo
- Application root: `/opt/zar/server`
- PocketBase binary: `/opt/zar/server/pocketbase`
- PocketBase data: `/opt/zar/server/pb_data/data.db`
- PocketBase auxiliary/log database: `/opt/zar/server/pb_data/auxiliary.db`
- Production migrations: `/opt/zar/server/pb_migrations`
- systemd unit: `/etc/systemd/system/zar-server.service`
- Caddy config: `/etc/caddy/Caddyfile`
- Verified backup script/service/timer: `/usr/local/sbin/zar-backup`, `/etc/systemd/system/zar-backup.{service,timer}`
- Local daily snapshots: `/backups/zar-daily/zar-YYYYMMDDTHHMMSSZ/`
- Disabled legacy cron and rollback evidence: `/root/zar-backup-automation-20261030T200203Z`
- Administrative access rollback/evidence: `/root/zar-admin-access-20261031T084900Z`
- Rate-limit production evidence: `/root/zar-rate-limit-production-20261101T195200Z`
- Rate-limit pre-change backup: `/backups/zar-daily/zar-20261101T195240Z/`
- Transactional-restore candidate staging (not installed): `/root/zar-restore-candidate-20261105-0004`
- Transactional-restore clone evidence: `/root/zar-transactional-restore-clone-20261105-0004` (311 files, approximately 2.3 MiB)
- Transactional-restore expected-state manifest SHA-256: `3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3`
- Public application URL: `https://app.titangold.ir`
- Alternate URL: `https://zar.185-126-202-104.sslip.io`

### Roadmap artifact

- Interactive roadmap: `C:\Users\simin\.cursor\projects\empty-window\canvases\zar-stabilization-roadmap.canvas.tsx`

Never put passwords, tokens, signing-key material, private keys, database contents, personal data, or secret configuration values in this handoff or in Git.

## 3. Baseline facts established

### Repository

- Flutter/Dart multi-platform application with Android, iOS, Windows, Linux, macOS and web scaffolding.
- Source includes local Drift/SQLite, PocketBase and dormant/opt-in Firebase paths.
- `server/pb_migrations` contains the reconciled production lineage and the four
  deployed stabilization migrations: two deletion locks, administrative
  trusted-proxy/superuser settings and the rate-limit policy.
- The local candidate adds a fifth stabilization migration plus
  two PocketBase hook files for transactional cloud restore. This candidate is
  not deployed, not production evidence and not yet a release artifact.
- CI at `.github/workflows/phase_a2_ci.yml` runs real PocketBase authorization
  and migration-lineage jobs alongside analyze, tests and a debug web build.
- README describes exact money handling (integer minor units) and exact gold decimal strings.
- The full Flutter baseline passed: 327 tests, zero failures. Raw line coverage is 57.16%; non-generated line coverage is 69.24%.
- The pre-deployment rate-limit checkpoint passed 331 tests with zero failures.
  After the cash-restore guard and blocking-dialog regression test were added,
  the complete suite passed 337 tests with zero failures on 2026-11-02; full
  analyzer had no findings.
- The current candidate passes the complete exact-tree Flutter
  suite (**345 tests**), the full analyzer, all three real-PocketBase server
  suites, the 24-test state/guard/canary suite (22 passed plus two expected
  platform skips), a separate real PocketBase commit → restart → replay test,
  Python syntax and shell syntax checks. GitHub run #261 (ID
  `42042024671`) passed both `pocketbase-authorization` and `flutter-checks` at
  exact code/evidence head `e9ee6e08372d6769b95b78dccff60c4aeb2246f5`.
- Android release guide exists, but actual signing-key possession, installed APK identity, and clean release build are not yet proven.
- Product documentation currently defines ZAR+ as an operational gold/currency assistant and explicitly excludes a full accounting ledger, profit/loss, tax and financial statements. The owner must confirm whether “accounting application” means this operational scope or a true general ledger before architecture changes.

### Production

- Ubuntu 24.04, PocketBase `v0.40.4`, Caddy, BIND9, Postfix/OpenDKIM and SSH are active.
- PocketBase is reverse-proxied by Caddy and now binds only to `127.0.0.1:8090`; direct external TCP 8090 is closed/filtered.
- PocketBase runs as locked system account `zarapp` with `0700/0600` data modes, write confinement, no effective capabilities and a `2.8 OK` systemd exposure score.
- SSH uses named `zaradmin`, public-key-only authentication; direct root/password authentication is disabled.
- Local backups use atomic verified systemd snapshots with 30-day/minimum-seven retention. The generated format passed isolated restore/reconciliation and the first natural timer run reported `BACKUP_OK`; copies still remain on the same server.
- Workspace and cash-journal deletion defects are contained. Public user signup remains enabled and requires an explicit policy decision.
- Public Caddy now denies the PocketBase dashboard, superuser name/ID routes and management APIs. Private Real-IP propagation and the loopback-only superuser whitelist are proven; operators use an SSH local tunnel.
- The tuned 11-rule rate-limit policy passed isolated boundary, natural-expiry,
  startup-burst, 500/400-operation batch, Caddy Real-IP, superuser and exact
  guarded deploy/recovery/rollback canaries. Exact-head CI, production
  preflight, guarded deployment and minute 0/5/15 observations then passed on
  2026-11-01. Production has `enabled=true`, `excludedIPs=[]`, no unexplained
  429/5xx in the bounded interval and `NRestarts=0`; rollback was not required.
- Installed-APK sign-in/startup and the Persian 429 message remain unproven;
  the server deployment must not be represented as a client release.
- No external monitoring/alerting channel exists yet. Tested recovery, containment, SSH, service and backup change/rollback evidence now exists.
- Production was changed only through the documented gated changes recorded below; each passed health/integrity/reconciliation checks and no rollback was required.
- Production does not contain the transactional-restore migration, hooks or
  explicit hook-path unit. It remains at exactly 11 rate rules and the earlier
  server-side cash update/delete lock; the local candidate expects 13. The
  branch client guard has not been verified in the installed Android APK.
- A read-only postflight at `2026-11-05T13:58:03Z` reconfirmed: service active,
  loopback health `200`, restore route `404`, both hook files and migration
  absent, no explicit hook arguments in the installed unit, and exactly 11
  enabled rate-limit rules. The production sanitized state SHA-256 was
  `de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`
  both before and after the final clone drill. No production state was changed.

## 4. Non-negotiable gates before production changes

1. Capture baseline checksums and versions for binary, migrations, service/Caddy configuration, APK and database schema.
2. Create a consistent pre-change backup set including database, migrations and operational configuration.
3. Restore that set in an isolated environment and run integrity/reconciliation checks.
4. Write the exact change, validation and rollback commands before executing the change.
5. Keep one verified SSH key session open during SSH hardening; test a second session before closing the first.
6. Apply one small production change at a time, record evidence, and stop on any unexpected result.
7. Do not rotate or expose secrets through shell output, Git, chat, or this document.

## 5. Current workstream and action log

### Completed

- 2026-10-28: Performed a read-only server inventory and service/schema/security audit.
- 2026-10-28: Verified the public HTTPS endpoints and TLS health.
- 2026-10-28: Verified local SQLite backup integrity with read-only checks; the full restore drill was subsequently completed on 2026-10-30.
- 2026-10-28 20:24 +03:30: Inspected GitHub repository metadata using the connected GitHub account.
- 2026-10-28 20:26 +03:30: Cloned `master` at `e60d68d` to the local working path above.
- 2026-10-28 20:28 +03:30: Created local branch `codex/stabilization-baseline`.
- 2026-10-28 20:29 +03:30: Read repository README, CI, server deployment guide, both tracked PocketBase migrations, Android release guide and prior Codex handoff.
- 2026-10-28 20:31 +03:30: Created this versioned handoff.
- 2026-10-28 20:34 +03:30: Re-verified the active production service and recorded binary, migration, service, proxy and backup checksums in `BASELINE.md`.
- 2026-10-28 20:35 +03:30: Confirmed the two tracked production migrations match Git (one byte-identical, one normalized-text-identical) and identified two production-only Persian email-template migrations.
- 2026-10-29 15:36 +03:30: Verified Flutter `3.47.2` and resolved dependencies with the committed lockfile.
- 2026-10-29 15:37 +03:30: `flutter analyze --no-fatal-infos` passed with no findings.
- 2026-10-29 15:48 +03:30: Full `flutter test --coverage` completed: 327 passed, zero failed; 57.16% raw and 69.24% non-generated line coverage.
- 2026-10-29 15:49 +03:30: Reproduced anonymous workspace deletion against disposable PocketBase 0.40.4 (`204`) and verified the proposed lock migration changes anonymous/member delete to `403` while member view/update remain `200`.
- 2026-10-29 15:50 +03:30: Confirmed member deletion of a cash-journal entry succeeds (`204`); recorded as the next server-integrity migration after reversal characterization.
- 2026-10-29 15:52 +03:30: Added local forward migration `1793260800_lock_workspace_deletion.js`, a real PocketBase authorization test and checksum-verified CI job. Migration `up / down 1 / up` and all API assertions pass locally.
- 2026-10-29 15:53 +03:30: Scoped all PocketBase snapshot/load/restore-discovery queries to the selected workspace and added a regression test covering all 14 requests. Targeted tests and analyzer pass.
- 2026-10-29 15:55 +03:30: Added the evidence-based findings register and updated the interactive stabilization roadmap.
- 2026-10-29 15:56 +03:30: Preserved the checkpoint in three local commits: `f3aab5d` (docs/handoff), `0c68859` (workspace deletion containment and CI integration test), and `088d86a` (workspace-scoped cloud queries).
- 2026-10-30 14:58 +03:30: Copied the latest server-created SQLite backup and operational/migration artifacts read-only into local quarantine. All known production migration and config hashes matched the baseline.
- 2026-10-30 15:01 +03:30: Restored the production-derived backup with PocketBase 0.40.4 in a disposable loopback-only environment. Health, SQLite integrity, domain references and all eight table count/content reconciliations passed with zero difference.
- 2026-10-30 15:03 +03:30: Recovered the two production-only email-template migrations byte-for-byte into the local branch. Fresh-install, production-clone and existing-developer migration lineages pass.
- 2026-10-30 15:05 +03:30: Added the non-destructive recovery verifier and exercised restore/reconciliation runbook. A deliberately wrong source hash is correctly rejected.
- 2026-10-30 15:10 +03:30: Added `1793347200_lock_cash_entry_deletion.js`. Disposable API tests prove cash create remains `200`, update/delete are `403`, the original survives, and a reversal entry can still be created (`200`). Production-clone restore and all migration lineages still pass with both security migrations pending.
- 2026-10-30 15:12 +03:30: Preserved the server/migration checkpoint in `87f4a6e` and the recovery verifier/runbook in `5af2907`. The working tree was clean before this ledger update.
- 2026-10-30 15:10 +03:30: Re-ran Flutter analysis, workspace-isolation tests, real PocketBase authorization/lineage tests and the production-clone restore; all passed. Drafted the exact production containment preflight, execution, stop and full-restore rollback plan. No production command was executed.
- 2026-10-30 15:15 +03:30: Owner confirmed there are no customers and no independent backup destination. Captured a fresh production SQLite backup, copied the full recovery set off-server to the owner's Windows computer, encrypted it with AES-256, restricted ACLs, decrypted it, verified all 10 manifest hashes and re-ran the isolated restore successfully. Recorded a temporary exception expiring before customer data or 2026-11-30.
- 2026-10-30 15:18 +03:30: Applied the two reviewed containment migrations to production during a 27-second maintenance interval. SQLite integrity, migration/rule state, record counts, internal/public health, restart count and logs all passed. Created, restored and encrypted a verified post-change recovery set. Rollback was not required.
- 2026-10-30 15:20 +03:30: Pushed `codex/stabilization-baseline` and opened Draft PR #3 against `master`. GitGuardian and the real PocketBase authorization job passed immediately; Flutter CI was still running at this checkpoint. No merge was performed.
- 2026-10-30 15:24 +03:30: Created and tested `zaradmin`, captured an off-server SSH/sudo rollback archive, kept a live root rollback session, installed and validated key-only SSH policy, reloaded SSH, proved new admin/sudo access, proved new root and password-only access are rejected, updated the local alias, and then closed the preserved root session. PocketBase remained active.
- 2026-10-30 15:30 +03:30: Proved the proposed PocketBase sandbox with an isolated canary, captured stopped-state database and full-data rollback artifacts, then moved the live service from root to locked system account `zarapp`, restricted writes to `pb_data`, changed data modes to `0700/0600` and bound port `8090` to loopback. Counts/migrations/integrity/public health/external port/log/restart gates all passed; downtime was approximately one second and the systemd exposure score improved from `9.6 UNSAFE` to `2.8 OK`. The disposable canary data copy was removed after validation.
- 2026-10-30 23:35 +03:30: Replaced the unsafe inline backup cron only after candidate success/failure/concurrency/retention tests and a successful installed systemd run. The generated atomic snapshot matched production and passed checksum, integrity, schema, counts, migrations and the full isolated PocketBase restore verifier. Timer is enabled for daily 03:00 UTC execution. Temporary unencrypted test copies were deleted after the machine-readable report was retained.
- 2026-10-31 12:18 +03:30: Observed the first natural backup timer run from 03:01 UTC with `BACKUP_OK`. A fresh pre-admin-change snapshot also passed checksum and immutable quick/integrity checks.
- 2026-10-31 12:19 +03:30: Deployed reviewed Caddy admin-route containment plus versioned trusted-proxy/superuser-IP settings. Public dashboard, superuser name/ID, schema, logs, backup, cron, SQL and impersonation routes return `404`; normal mobile routes retain baseline behavior. Outside Real-IP, forged-header rejection, SSH tunnel, external port closure, counts, migration delta, SQLite integrity, journals and `NRestarts=0` all passed. PocketBase restart-to-healthy was 559 ms; rollback was not required.
- 2026-10-31 12:27 +03:30: GitHub Actions run #252 completed successfully at `859ece7`; both `flutter-checks` and `pocketbase-authorization` passed.
- 2026-10-31 17:31 +03:30: Rejected the unsafe disabled-default rate rules after proving they would break internal batch subrequests. Added a guarded ZAR-specific policy and Persian 429 handling. Disposable production clones passed exact action boundaries, IP separation, natural 60-second and batch-window reset, two simultaneous startup snapshots, 500-operation and two 400-operation authenticated batches, atomic rollback, Caddy forged-header overwrite, loopback superuser behavior, clean logs/integrity and exact migration down. One Caddy canary attempt was explicitly aborted on an occupied admin port and repeated successfully with `admin off`. Production remains unchanged. Full local result: 331 tests passed; analyzer clean.
- 2026-10-31 17:31 +03:30: Confirmed a separate P1 recovery defect: cloud snapshot replacement cannot restore existing append-only cash rows, although its single batch rolls back atomically. Recorded fail-closed containment and server-side/new-workspace import as required work.
- 2026-10-31 17:41 +03:30: Added a no-defaults, hash/settings/history/count/service-bound rollback script and exercised the exact stop/down/remove/start-to-health path on disposable production clones. Fail-closed attempts exposed and corrected journal-output, service-path and missing-`auxiliary.db` assumptions; the final full two-database run passed settings/history/count/restart/integrity/log reconciliation. Production stayed active with candidate history `0` and no candidate file. GitHub run #254 at `1c3fb7b` also passed both jobs; final exact-head CI was still pending at this checkpoint and later passed as run #257.
- 2026-10-31 23:34 +03:30: Added a shared-lock, no-defaults guarded deploy wrapper that keeps the candidate outside live migrations until stopped-state verification, runs explicit migrate-up, and has exact recovery state machines for both not-applied and applied-but-unhealthy failures. The frozen deploy/rollback scripts passed both forced failpoints, successful deploy, exact rollback, two-database integrity, history/count/restart and empty-journal reconciliation on a full production clone. Production remained unchanged at this checkpoint; the separately recorded guarded deployment passed on 2026-11-01.
- 2026-11-01: GitHub Actions run #257 (ID `41343818686`) passed `flutter-checks` and `pocketbase-authorization` at exact head `8c060542a88b37b26ff1637ea9c56fde1bf4460b`.
- 2026-11-01 19:55–20:10 UTC: The production rate-limit preflight created and verified a fresh backup, matched the expected settings/history/rules/counts and both database integrity results, then the pinned guarded deploy installed only `1793437200_enable_rate_limits.js`. The exact 11 rules remained enabled through minute 0, 5 and 15; services/health/admin denial/counts/integrity/restarts stayed correct, no HTTP 429 or status greater than or equal to 500 appeared in the bounded interval, and rollback was not required.
- 2026-11-01: Copied the 81-entry production evidence set off-server and verified its internal hashes and archive SHA-256 `7877588bbee36233c854fa45b7dfa761eb7252179f4166d1313b7efc697adc95`. This operational archive does not close the same-host disaster-recovery exception.
- 2026-11-01: Added client fail-closed containment for cash-containing cloud restore: incoming or currently observed cash produces a typed Persian controlled-recovery error before any batch/write, and regression tests cover both denied paths plus the non-cash path. The client GET-to-batch multi-device race remains open P1 and requires a server-side transactional revision/import design.
- 2026-11-02: Re-ran the complete Flutter suite after combining the cash-restore containment and production-evidence update: 337 tests passed with zero failures; full analyzer reported no findings.
- 2026-11-02: Added a local-only transactional cloud-restore candidate: one
  compare-and-swap transaction replaces all seven domain collections and
  creates a private idempotency receipt; password re-authentication,
  single-member authorization, membership immutability, stale-state rejection,
  bounded input and ambiguous-result retry are being hardened. Added a
  service-stopped deployment/rollback plan and explicit hook paths with hot
  reload disabled. Production was not changed; full tests, clone rehearsal and
  exact-head CI remained pending at that checkpoint.
- 2026-11-03: Completed the local server-side accounting validator and
  destructive PocketBase coverage. Authorization, migration-lineage and
  transactional-restore suites all pass, including cash replacement,
  stale/concurrent writes, idempotency, transaction rollback, malformed
  snapshots, shared-workspace denial, isolated receipt recovery and refusal to
  migrate down after a receipt exists.
- 2026-11-03: Extended `verify_recovery_set.py` to bind and hash the exact hook
  directory, reconcile receipt count/metadata hashes without payloads and
  restart the restored service with hot reload disabled. The current local
  files passed against the historical production-derived snapshot; see
  `TRANSACTIONAL-RESTORE-LOCAL-EVIDENCE-2026-11-03.md`. Because that snapshot
  predates the production 11-rule deployment, it is supporting evidence rather
  than the required final `11`→`13` rehearsal.
- 2026-11-03: Independent security review found one high-severity client
  ambiguity defect. It was remediated so that after a possibly committed first
  request, every non-verifiable retry—including all tested 4xx classes—remains
  `cloud_restore_outcome_unknown`. Targeted regression tests and analyzer pass;
  a fresh independent follow-up review remains a release gate.
- 2026-11-03: Re-ran the complete Flutter suite after the security remediation:
  345 tests passed with zero failures and full analyzer reported no findings.
- 2026-11-03 12:36 UTC: Read-only production verification confirmed active
  health, exactly 11 enabled rate rules, no restore route, no candidate
  migration/hooks and no candidate service arguments. Production was not
  mutated.
- 2026-11-05 01:48–01:50 +03:30: Ran the preliminary root-owned, no-default
  transactional-restore harness against fresh SQLite backup copies of current
  production under a unique transient systemd unit and loopback port. The
  functional matrix passed, but this run was deliberately superseded rather
  than accepted as final when security review began.
- 2026-11-05: The first dedicated guarded-tooling security review found four
  blockers: privileged-input/root-trust gaps, fail-open containment recovery,
  insufficient protection against targeting production port `8090`, and missing
  proof that non-rate-limit PocketBase settings stayed unchanged. The tools were
  changed to validate every privileged input and parent, fail closed on
  containment error, bind the canary to a disposable systemd identity/tree and
  pin the canonical non-rate settings hash. A fresh rehearsal passed, but it was
  also superseded pending the follow-up review.
- 2026-11-05: The follow-up security review found four further blockers:
  evidence-file symlink writes before evidence validation, a pre-stop
  containment recovery gap, restart of an unvalidated database state and a
  disposable-path alias that could reach production data. Evidence directories
  are now root-chain validated before traps, device/inode pinned and written
  with no-follow/exclusive semantics; containment and rollback are armed before
  stop; invalid state remains stopped; receipt-bearing recovery requires a
  valid contained profile and exact artifacts; canary paths, executable and
  both database inodes are bound to one real disposable tree.
- 2026-11-05: Independent closure audits additionally caught and closed
  cross-named production-database hardlinks, fail-open rollback restart paths,
  a receipt/baseline mismatch in deploy recovery and two asynchronous harness
  cleanup/readiness races. Final read-only audits reported no remaining blocker.
  The 24-test state/guard/canary suite passed with two expected platform skips,
  the real PocketBase commit → restart → replay test passed separately, and all
  three real-PocketBase authorization, lineage and transactional-restore suites
  passed.
- 2026-11-05 17:24–17:28 +03:30: Ran final rehearsal `0004` from fresh current-
  production SQLite backups using transient unit
  `zar-restore-clone-20261105-0004.service` on `127.0.0.1:18093`. The matrix
  covered six ordered deploy failpoints; symlink, writable-parent and untrusted-
  input refusal without restart; invalid-state stop; receipt-bearing deploy
  recovery; pre-receipt rollback; three rollback failure recoveries; pre-stop
  and post-start containment failures; ambiguous containment; real commit,
  restart and replay; and wrapper/raw-down refusal after a receipt. Every case
  passed. Production pre/post sanitized SHA-256 remained exactly
  `de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`;
  candidate production files/history remained absent and the private canary
  state was deleted.
- 2026-11-05: Preserved final sanitized evidence in the 365-entry local archive
  recorded above. Archive inspection found zero symlinks, unsafe paths, database
  files or private-state files; archive SHA-256 is
  `a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`.
- 2026-11-06 11:17–11:18 +03:30: Performed a fresh read-only production
  postflight while finalizing the programmer handoff. `zar-server`, Caddy and
  `zar-backup.timer` were active, the timer was enabled, `NRestarts=0`, loopback
  health returned `200`, and PocketBase listened only on `127.0.0.1:8090`.
  Transactional-restore migration/hooks remained absent. The natural
  2026-11-06 backup `zar-20261106T030011Z` reported a successful unit result;
  strict SHA-256 verification returned `data.db: OK`, SQLite quick-check was
  `ok`, and the snapshot directory/file modes were `0700/0600`. No production
  state was changed.

### Local commit checkpoint

- `f3aab5d` — `docs(stabilization): add baseline findings and handoff`
- `0c68859` — `fix(server): prevent workspace deletion through record API`
- `088d86a` — `fix(cloud): scope snapshots to selected workspace`
- `87f4a6e` — `fix(server): reconcile migrations and protect cash history`
- `5af2907` — `feat(recovery): add isolated restore verification`
- `d3f8e92` — `docs(stabilization): record recovery checkpoint`
- `0699bfd` — `docs(stabilization): add production containment plan`
- `e71b69a` — `feat(recovery): add encrypted local bundle fallback`
- `14cb8d9` — `security(server): contain PocketBase admin access`
- `6d29988` — `fix(server): block superuser collection id alias`
- `859ece7` — `docs: tighten admin containment rollback guards`
- `3a3728a` — `security(server): add tested rate limit policy`
- `1c3fb7b` — `docs(stabilization): record rate limit canary`
- `58f7238` — `ops(server): prove guarded rate limit rollback`
- `3f2a54b` — `docs(stabilization): refresh handoff after rollback proof`
- `8c06054` — `ops(server): guard rate limit deployment`
- `2531bd3` — `fix(backup): fail closed on cloud cash restore`
- `f95c49f` — `docs(stabilization): record rate limit production gate`
- `31eadf7` — `feat(restore): add transactional cloud recovery`
- `40ffe3b` — `docs(stabilization): record restore candidate evidence`
- `e9ee6e0` — `ops(restore): prove guarded transactional recovery`
- The guarded tooling and 2026-11-05 final `0004` evidence are published at
  exact checkpoint `e9ee6e08372d6769b95b78dccff60c4aeb2246f5`; GitHub Actions
  run #261 passed both jobs for that exact checkpoint. Later documentation-only
  commits must still be resolved from the Draft PR head before relying on them.
- The branch is published in Draft PR #3 and remains unmerged. Production
  contains the four reviewed stabilization migrations (two deletion locks,
  admin-access settings and rate limiting); `master` will remain behind until
  review and an explicit merge decision.

### Running now

- Publish the consolidated programmer handoff and keep Draft PR #3 unmerged;
  exact-head CI for the code/evidence checkpoint is green. Do not merge or
  deploy without the owner's explicit, separate decision. The two dedicated
  security-review remediation rounds and subsequent independent closure audits
  are complete with no remaining blocker reported in their reviewed boundaries.
- Keep production unchanged. The fresh current-production clone/tooling gate is
  complete; post-receipt recovery remains forward-only and must preserve
  receipts.

### Next safe actions

1. Give the next programmer `PROGRAMMER-HANDOFF.md`, independently verify the
   Draft PR head and CI, and do not merge Draft PR #3 without the owner's
   explicit decision.
2. If the owner later authorizes production deployment, create a fresh verified
   recovery set and execute the prewritten guarded maintenance window. The
   passing clone is evidence, not deployment authorization.
3. Inspect the installed Android APK and prove package/version/signature,
   sign-in/startup and Persian 429 behavior before client release.
4. Decide whether public signup should remain enabled in the pre-customer environment.
5. Add external monitoring and define server-enforced audit, reversal,
   concurrency and invariant behavior.
6. Replace the temporary independent-backup exception before customer data,
   launch or 2026-11-30.

## 6. Known P0/P1 queue

### P0 — contain before normal development

- Close unauthenticated deletion of `zar_workspaces` using a versioned, tested PocketBase migration. **Completed in production on 2026-10-30; delete rule verified `NULL`.**
- Decide and enforce the intended signup policy; do not rely on an accidental empty rule.
- Establish an off-site encrypted backup. **Pre/post encrypted bundles now exist on the owner's Windows computer under a temporary pre-customer exception; independent placement and a second-operator drill remain mandatory before launch/customer data.**
- Restrict SSH to a non-root administrative path with key authentication, then disable password/root login safely. **Completed and independently retested on 2026-10-30.**
- Run PocketBase as a dedicated least-privilege service user and restrict `pb_data` permissions. **Completed and independently retested on 2026-10-30.**
- Bind PocketBase to loopback. **Completed and independently retested on 2026-10-30.** Public admin/management routes and superuser traffic were additionally contained behind Caddy, an SSH tunnel and loopback whitelist on 2026-10-31.
- Prevent the app from presenting cloud cash restore as supported while the
  append-only server correctly rejects its deletes. **Client fail-closed
  containment and Persian controlled-recovery messaging are implemented and
  tested in the published baseline. A local server-side transactional
  candidate now addresses the GET-to-batch race, but production remains on the
  containment path until this checkpoint is committed/published, exact-head CI
  and an explicit production-deployment approval pass. Two security-review
  remediation rounds, independent closure audits and the fresh current-
  production clone/recovery-tooling gates passed on 2026-11-05.**

### P1 — establish a reliable source of truth

- Production migration history is reconciled locally: the two missing email-template migrations now match production byte-for-byte. Sanitized Caddy, PocketBase and backup systemd configurations are versioned; alerting and environment-specific secret custody remain open.
- Prove clean builds/tests, record the Flutter/Android/JDK toolchain and create dependency/SBOM evidence.
- Capture the currently installed APK version, package, signing-certificate fingerprint and artifact hash from a trusted device/build archive.
- Protect `master`, require CI review, sign releases/commits as policy permits, and create versioned releases/checksums.
- Add monitoring for service health, 5xx/latency, disk, certificate, backup age, auth anomalies and restart loops.

## 7. Accounting/operational integrity constraints

- Never use binary floating point for money or gold quantities.
- Financial/operational writes that form one business event must be atomic.
- Retries must be idempotent and protected by unique constraints.
- Conflicting device writes need explicit version/concurrency handling.
- Posted/historical events should not be silently edited or hard-deleted; corrections must be traceable reversals/adjustments.
- Every critical business invariant must have a stable identifier, a golden-data example and an automated test.
- Restore/migration acceptance requires zero unexplained reconciliation difference.

Scope conflict requiring owner decision: current repository documentation says this is not a general-ledger/accounting product. Do not add ledger, tax, profit/loss or financial statements until the owner confirms the intended accounting scope and a qualified accountant validates the domain rules.

## 8. Resume procedure after interruption or usage limit

1. Read this file completely.
2. In the local clone, run `git status --short --branch` and confirm the active branch is `codex/stabilization-baseline`.
3. Confirm `git rev-parse master` still equals the recorded baseline or record any upstream change before rebasing/merging.
4. Read the latest entries in the action log and finding register when added.
5. Do not repeat production discovery unless evidence is stale; every further server mutation requires its own scoped plan, fresh recovery evidence and rollback gate.
6. Continue from the single item marked “next safe action,” update this handoff, then mirror it to the `outputs` path.
7. Before committing, run the applicable format/analyze/test checks and record their exact result.
8. Do not push, open a PR, merge, deploy, reboot or alter production unless that specific step has been prepared with evidence and is within the owner-approved workstream.

## 9. Definition of stabilization complete

- No open Critical/High security finding; lower risk has an owner, due date and written acceptance.
- Critical business invariants and authorization boundaries are covered by automated tests.
- Clean, reproducible, signed APK and versioned server artifacts can be produced from Git.
- Production deploy, migration, rollback and off-site restore are rehearsed in staging.
- Restore and migration reconciliation has zero unexplained difference.
- Operations, security, architecture, data dictionary, API/auth matrix, testing, release, backup/restore and incident runbooks are complete and exercised by a second operator.
- A release candidate completes a 7–14 day pilot/soak with no P0/P1 incident.
- Product owner, accounting/domain owner, security reviewer and operations owner approve the release evidence.

## 10. Limitations and unresolved inputs

- No direct inspection of the Android APK currently installed on the user's phone has been performed.
- Production signing key possession and backup have not been verified.
- The local recovery drill, 30-day/minimum-seven automation and first natural timer execution passed, but scheduled production snapshots remain on the same server.
- Business scope (operational assistant versus full accounting ledger) is not yet confirmed.
- Legal/tax/retention requirements and authoritative jurisdiction are not yet confirmed.
- RPO, RTO, maximum tolerable downtime and availability SLO require owner decisions.
- Public signup intent requires owner confirmation; meanwhile it is treated as a risk, not an assumed feature.
- GitHub branch protection and required-check policy are currently absent or unverified beyond the repository API response.

