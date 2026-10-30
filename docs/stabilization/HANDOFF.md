# ZAR+ Stabilization Handoff

Last updated: 2026-10-30 15:20 +03:30 (Asia/Tehran)
Status: **IN PROGRESS — first production containment change passed; broader hardening remains**
Change freeze: no feature work and no direct production mutation until the backup/restore and rollback gates below pass.

## 1. Objective

Stabilize ZAR+ before further product development: establish a reproducible source-of-truth, prevent data loss and unauthorized access, characterize current behavior, close critical security risks, verify accounting/operational invariants, complete operational documentation, and produce auditable release gates.

The defensible completion statement is not “there are no bugs.” It is: all known critical risks and critical user journeys are covered by evidence, tests, recovery drills, and explicit acceptance gates.

## 2. Authoritative locations

### GitHub

- Repository: `https://github.com/sepehrraeisi/ZAR`
- Draft stabilization PR: `https://github.com/sepehrraeisi/ZAR/pull/3`
- Default branch: `master`
- Baseline commit: `e60d68dda3c1876dc5af99e36c1f455b76fd8a50`
- Baseline commit is unsigned.
- `master` is currently reported as unprotected.
- Open pull requests/issues/releases at baseline: none.
- Existing remote branch: `codex/phase-a2-ux` at `b45e1ff810ade8e2ca28308b7bbe9592ce6e3ad0`.

### Local working copy

- Clone: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\ZAR`
- Current local branch: `codex/stabilization-baseline`
- Handoff (canonical): `docs/stabilization/HANDOFF.md`
- Baseline evidence manifest: `docs/stabilization/BASELINE.md`
- Findings register: `docs/stabilization/FINDINGS.md`
- Restore/reconciliation runbook: `docs/stabilization/RESTORE-RUNBOOK.md`
- Production containment change plan: `docs/stabilization/PRODUCTION-CONTAINMENT-CHANGE-PLAN.md`
- Production containment evidence: `docs/stabilization/PRODUCTION-CONTAINMENT-EVIDENCE-2026-10-30.md`
- SSH hardening plan: `docs/stabilization/SSH-HARDENING-PLAN.md`
- Temporary pre-customer recovery exception: `docs/stabilization/TEMPORARY-RECOVERY-EXCEPTION.md`
- Recovery verifier: `server/tools/verify_recovery_set.py`
- Local machine-readable recovery evidence: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\recovery-evidence-20261030\restore-report.json`
- Sanitized server audit notes: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\server-review-notes.md`
- User-facing handoff mirror: `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\outputs\ZAR-STABILIZATION-HANDOFF.md`

### Production server

- SSH alias: `zar-vps`
- Host: `185.126.202.104`
- SSH user currently used for audit: `root`
- Application root: `/opt/zar/server`
- PocketBase binary: `/opt/zar/server/pocketbase`
- PocketBase data: `/opt/zar/server/pb_data/data.db`
- PocketBase auxiliary/log database: `/opt/zar/server/pb_data/auxiliary.db`
- Production migrations: `/opt/zar/server/pb_migrations`
- systemd unit: `/etc/systemd/system/zar-server.service`
- Caddy config: `/etc/caddy/Caddyfile`
- Backup cron: `/etc/cron.d/zar-backup`
- Local backups: `/backups/zar-YYYY-MM-DD.db`
- Public application URL: `https://app.titangold.ir`
- Alternate URL: `https://zar.185-126-202-104.sslip.io`

### Roadmap artifact

- Interactive roadmap: `C:\Users\simin\.cursor\projects\empty-window\canvases\zar-stabilization-roadmap.canvas.tsx`

Never put passwords, tokens, signing-key material, private keys, database contents, personal data, or secret configuration values in this handoff or in Git.

## 3. Baseline facts established

### Repository

- Flutter/Dart multi-platform application with Android, iOS, Windows, Linux, macOS and web scaffolding.
- Source includes local Drift/SQLite, PocketBase and dormant/opt-in Firebase paths.
- `server/pb_migrations` contains the two original migrations, two byte-identical recovered production email-template migrations and two new undeployed deletion locks for workspaces and cash-journal entries on the current local branch.
- CI file exists at `.github/workflows/phase_a2_ci.yml`; the current local change adds real PocketBase authorization and migration-lineage jobs alongside analyze, tests and a debug web build.
- README describes exact money handling (integer minor units) and exact gold decimal strings.
- The full Flutter baseline passed: 327 tests, zero failures. Raw line coverage is 57.16%; non-generated line coverage is 69.24%.
- Android release guide exists, but actual signing-key possession, installed APK identity, and clean release build are not yet proven.
- Product documentation currently defines ZAR+ as an operational gold/currency assistant and explicitly excludes a full accounting ledger, profit/loss, tax and financial statements. The owner must confirm whether “accounting application” means this operational scope or a true general ledger before architecture changes.

### Production

- Ubuntu 24.04, PocketBase `v0.40.4`, Caddy, BIND9, Postfix/OpenDKIM and SSH are active.
- PocketBase is reverse-proxied by Caddy, but currently binds to `0.0.0.0:8090`; UFW blocks direct public access.
- Service currently runs as `root` without meaningful systemd hardening.
- Production database and parent permissions are too broad (`0644` database files observed).
- SSH currently permits direct root and password authentication; the host is under continuous brute-force traffic.
- Backups are local-only, same-disk, seven-day retention and cover only `data.db`. A local production-derived restore/reconciliation drill passed on 2026-10-30, but no encrypted off-site recovery set or second-operator drill exists.
- Production schema has a critical authorization defect: `zar_workspaces.deleteRule` is empty/public. Public user signup is also enabled.
- No production monitoring/alerting or tested incident/rollback runbook was found.
- Server audit was read-only. No production change has been made in this stabilization session.

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
- 2026-10-28: Verified local SQLite backup integrity with read-only checks; full restore drill remains pending.
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

### Local commit checkpoint

- `f3aab5d` — `docs(stabilization): add baseline findings and handoff`
- `0c68859` — `fix(server): prevent workspace deletion through record API`
- `088d86a` — `fix(cloud): scope snapshots to selected workspace`
- `87f4a6e` — `fix(server): reconcile migrations and protect cash history`
- `5af2907` — `feat(recovery): add isolated restore verification`
- `d3f8e92` — `docs(stabilization): record recovery checkpoint`
- `0699bfd` — `docs(stabilization): add production containment plan`
- `e71b69a` — `feat(recovery): add encrypted local bundle fallback`
- All implementation and recovery changes through the production containment gate are committed or included in the current evidence update.
- The branch is published in Draft PR #3 and remains unmerged. Production contains the two reviewed migrations; `master` will remain behind until CI, review and an explicit merge decision.

### Running now

- Monitor Draft PR #3 CI and address only evidence-backed failures; do not merge automatically.
- Observe post-change service health and preserve the pre/post encrypted recovery bundles.
- Design of the broader reversal/tombstone and append-only audit model for remaining historical collections.
- Prepare the next separate hardening plans; do not combine SSH, service-user, filesystem and proxy changes.

### Next safe actions

1. Complete Draft PR #3 CI/review; do not merge without an explicit decision.
2. Decide whether public signup should remain enabled in the pre-customer environment.
3. Prepare separate change plans for non-root SSH administration, service-user/filesystem hardening and loopback/admin-UI restriction.
4. Define server-enforced audit and reversal behavior for the remaining historical collections.
5. Replace the temporary backup exception before customer data, launch or 2026-11-30.

## 6. Known P0/P1 queue

### P0 — contain before normal development

- Close unauthenticated deletion of `zar_workspaces` using a versioned, tested PocketBase migration. **Completed in production on 2026-10-30; delete rule verified `NULL`.**
- Decide and enforce the intended signup policy; do not rely on an accidental empty rule.
- Establish an off-site encrypted backup. **Pre/post encrypted bundles now exist on the owner's Windows computer under a temporary pre-customer exception; independent placement and a second-operator drill remain mandatory before launch/customer data.**
- Restrict SSH to a non-root administrative path with key authentication, then disable password/root login safely.
- Run PocketBase as a dedicated least-privilege service user and restrict `pb_data` permissions.
- Bind PocketBase to loopback and restrict the admin UI.

### P1 — establish a reliable source of truth

- Production migration history is reconciled locally: the two missing email-template migrations now match production byte-for-byte. Sanitized, hardened operational configuration still needs to be versioned.
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
- The local recovery drill passed, but the only automated production backups remain on the same server with seven-day retention.
- Business scope (operational assistant versus full accounting ledger) is not yet confirmed.
- Legal/tax/retention requirements and authoritative jurisdiction are not yet confirmed.
- RPO, RTO, maximum tolerable downtime and availability SLO require owner decisions.
- Public signup intent requires owner confirmation; meanwhile it is treated as a risk, not an assumed feature.
- GitHub branch protection and required-check policy are currently absent or unverified beyond the repository API response.

