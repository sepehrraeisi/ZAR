# ZAR+ Stabilization Findings Register

Updated: 2026-10-30 15:18 +03:30 (Asia/Tehran)
Baseline source: `e60d68dda3c1876dc5af99e36c1f455b76fd8a50`  
Working branch: `codex/stabilization-baseline`

This register is evidence-driven. “Locally fixed” means code and tests exist only in the local branch; it does **not** mean production has changed.

## Verified quality baseline

- Flutter: `3.47.2`, Dart toolchain from the stable Flutter release.
- `flutter pub get --enforce-lockfile`: passed.
- Baseline `flutter analyze --no-fatal-infos`: passed with no findings.
- Full baseline `flutter test --coverage`: **327 tests passed**, zero failures, 511.5 seconds.
- Raw line coverage: `10,058 / 17,595 = 57.16%`.
- Non-generated line coverage (excluding Drift `.g.dart`): `8,617 / 12,445 = 69.24%`.
- Critical coverage gaps: PocketBase auth service `0%`, cloud shell `0%`, backup screen `0%`, PocketBase repository `22.8%` at baseline.
- PocketBase `0.40.4` isolated integration tests: passed, including security migration `up / down 2 / up` and supported migration lineages.

The green baseline is valuable but does not prove production safety. Existing tests are strong around exact numeric domain behavior, local Drift transactions, projections, UI and backup codecs; they are weak around real PocketBase authorization, multi-device concurrency, Android data protection and disaster recovery.

## Critical and P0 findings

### ZAR-SEC-001 — public workspace deletion

- Severity: Critical.
- Evidence: `server/pb_migrations/1758400000_zar_collections.js:43` sets `deleteRule: ''`.
- Real integration reproduction: anonymous `DELETE` returned HTTP `204`; the workspace was gone.
- Production: **contained on 2026-10-30**; `deleteRule=NULL` verified after migration and restart.
- Local remediation: `server/pb_migrations/1793260800_lock_workspace_deletion.js` sets the rule to `null` in both migration directions.
- Regression evidence: anonymous delete `403`, member delete `403`, member view/update remain `200`, record survives.
- Status: **fixed in production and tested**. The Git branch still requires remote publication/review.
- Production gate: verified full backup/restore point, migration checksum, maintenance plan, health/auth test and rollback procedure.

### ZAR-DATA-001 — cloud reads/restores were not scoped to the selected workspace

- Severity: P0 data isolation/integrity.
- Evidence: baseline `lib/data/pocketbase/zar_pocketbase_repository.dart:80-110` listed each collection without a workspace filter; restore discovery at baseline lines `137-155` did the same.
- Impact: a user who is a member of multiple workspaces could load a mixed snapshot; restoring one workspace could delete records visible from another.
- Local remediation: every cloud snapshot read and restore-discovery query now uses `workspace='<selected id>'`.
- Regression evidence: `test/zar_pocketbase_repository_test.dart` proves all 14 load/restore discovery requests are scoped to `w1`.
- Status: **locally fixed in commit `088d86a`; targeted tests and analyzer pass; not pushed or released**.

### ZAR-DATA-002 — multi-device last-write-wins can silently lose changes

- Severity: P0 for the advertised cloud/multi-device path.
- Evidence: `_upsert` performs an unconditional PATCH with no revision, ETag, compare-and-swap or idempotency key; the app has no realtime subscription or conflict workflow.
- Impact: two phones can overwrite completion, cancellation, reminder or record changes without warning.
- Required remediation: server-issued revision, optimistic concurrency, explicit conflict handling and idempotency keys for business writes.
- Required regression: two clients read revision N; the first update succeeds and the stale second update is rejected with a recoverable conflict.
- Status: open; architectural decision required.

### ZAR-DATA-003 — server does not enforce critical domain invariants

- Severity: P0/High integrity.
- Evidence: PocketBase stores a free-form `data` JSON field and rules only check workspace membership. A member or stolen member token can bypass Dart validations using the API directly.
- Parity gap: local Drift validates cash, allocations and related writes transactionally; cloud save paths do not enforce the same rules.
- Impact: invalid references, forged actor fields, outer/inner ID mismatch, impossible state transitions and unbalanced business state can be stored.
- Required remediation: versioned server command/API boundary with schema validation, invariant checks and atomic transactions; shared parity suite across local and cloud repositories.
- Status: open.

### ZAR-DATA-004 — historical records are deletable and audit evidence is absent

- Severity: P0/High.
- Evidence: normal members have delete rights on financial collections. `zar_cash_entries` blocks updates but permits member deletion; a real isolated API test returned `204` for cash-entry deletion.
- `auditAction` parameters in the PocketBase repository are ignored; actor identity is also recorded as `local-user` in cloud presentation paths.
- Required remediation: deny hard delete for financial/history collections, introduce reversal/tombstone flows, append-only audit events, server time, authenticated actor, reason, request/idempotency ID and before/after linkage.
- Local containment in commit `87f4a6e`: `1793347200_lock_cash_entry_deletion.js` denies hard deletion in both migration directions. Real API regression proves create `200`, update/delete `403`, original record survival and reversal create `200`.
- Status: cash-journal update/delete is **contained in production and tested**. Hard delete for other historical collections and the full audit design remain open.

### ZAR-DATA-005 — workspace bootstrap is non-atomic and non-idempotent

- Severity: P0/P1.
- Evidence: `lib/features/auth/zar_cloud_shell.dart:89-100` creates a workspace, then patches the user in a separate request.
- Impact: network loss or simultaneous first launch can create orphan or duplicate workspaces.
- Required remediation: one server-side transactional/idempotent bootstrap command with a deterministic ownership constraint.
- Status: open.

## High findings

### ZAR-DATA-006 — cloud snapshots can mix revisions

- Seven collections are read independently and concurrently; concurrent writes can produce a snapshot whose deals, settlements, allocations and cash entries are from different revisions.
- Required: consistent snapshot/revision protocol and reconciliation checks.

### ZAR-DATA-007 — allocation replacement can become partially applied

- More than 400 delete/create operations are split into independent transactions. Failure after the first batch leaves partial state.
- Required: server-side atomic command or versioned replacement object; inject failure in regression tests.

### ZAR-DATA-008 — completed/posting state is mutable

- Client mappings and server update rules permit previously completed records to be reopened/cancelled or rewritten.
- Required: approved lifecycle transition matrix, period lock and reversal-only correction for posted history.

### ZAR-MOB-001 — session token and local financial data protection are insufficient

- PocketBase token is stored in `SharedPreferences` (`zar_pocketbase_auth_service.dart:36-40, 122-137`) rather than platform secure storage.
- Local SQLite is not encrypted.
- Android manifest has no explicit backup/data-extraction policy, so database/preferences may enter device backup.
- JSON export/share is plaintext and not tamper-evident.
- Required: Android Keystore-backed token storage, explicit backup rules, data classification, encrypted/authenticated exports where required, and documented recovery trade-offs.

### ZAR-OPS-001 — production service hardening is below baseline

- PocketBase previously ran as root, bound `0.0.0.0:8090`, and stored its database as `0644`. **Contained on 2026-10-30:** locked `zarapp` service account, loopback-only listener, `0700` data directory, `0600` database, empty capabilities, write confinement and a `2.8 OK` systemd exposure score.
- SSH previously permitted password and direct root login under sustained brute-force traffic. **Contained on 2026-10-30:** named `zaradmin`, key-only authentication, root login disabled, password authentication disabled, `MaxAuthTries=3`, `LoginGraceTime=30`.
- Admin UI is publicly reachable, although authentication is required.
- Required next: rate limiting and admin UI access restriction.

### ZAR-REC-001 — backups are not disaster-recovery ready

- Initial backups were local, same-disk, seven-day copies of only `data.db` with unsafe deletion scope and no checksum/integrity gate.
- All captured files passed SQLite `quick_check`.
- A production-derived backup was successfully restored and reconciled in isolation on 2026-10-30 with zero domain-table differences; the source hash remained unchanged and PocketBase health passed.
- The local drill is now reproducible through `server/tools/verify_recovery_set.py` and `docs/stabilization/RESTORE-RUNBOOK.md`.
- **Contained locally on 2026-10-30:** versioned atomic systemd backup timer, `0600` snapshots, SHA-256, metadata, quick/integrity/schema verification, exact-name 30-day/minimum-seven retention, no-network sandbox and a successful isolated restore of the generated format.
- The first naturally scheduled timer event is still pending observation; the installed systemd service run passed.
- Off-site encrypted replication, automated age monitoring, owner-approved RPO/RTO and a second-operator drill still do not exist.
- Required: full recovery set, 3-2-1 placement, encryption, retention, automated age/integrity monitoring and isolated restore with zero unexplained reconciliation difference.

### ZAR-CI-001 — release/supply-chain controls are incomplete

- `master` is unprotected; baseline commit is unsigned; no releases exist.
- CI previously used floating Flutter stable and `pub get` without lock enforcement; the local change now adds `--enforce-lockfile` and a checksum-verified PocketBase authorization job.
- Actions remain tag-pinned rather than commit-SHA-pinned; no SAST, secret scan, dependency vulnerability scan, SBOM or provenance exists.
- Required: protected branch, required reviews/checks, pinned toolchain/actions, SBOM, secret/dependency scans, signed release artifacts and provenance.

## Medium findings and constraints

- PocketBase client accepts non-HTTPS server URLs; release builds should reject cleartext except explicit local development.
- Cloud restore rejects datasets requiring more than 500 operations; a versioned large-dataset strategy is needed.
- UI defaults most non-Toman currencies to scale 2 even though the domain model supports scales 0–6.
- HTTP operations lack explicit request timeouts/cancellation and a documented retry budget.
- Two production-only Persian email-template migrations are not yet in Git.
- No APK hash/signing-certificate fingerprint from the installed phone has been captured; signing-key possession remains unverified.

## Scope decision required

Repository documentation calls ZAR+ an operational assistant and explicitly excludes a general ledger, profit/loss, tax, cost basis and financial statements. The owner describes it as accounting software. Before architectural expansion, the owner and a qualified accountant must confirm whether the stabilization target is:

1. the current operational gold/currency workflow with exact balances and auditability; or
2. a true accounting/general-ledger product with jurisdiction-specific posting and reporting.

Stabilization of security, recovery and current data integrity can continue without that decision. New accounting behavior cannot.

## Next implementation order

1. Push the complete checkpoint and open a PR so GitHub is no longer behind the deployed containment migrations.
2. Decide and enforce the intended public-signup policy.
3. Restrict the public admin UI, add rate limiting/monitoring, and replace the temporary off-site recovery exception before customer data or 2026-11-30. Hardened PocketBase and backup systemd artifacts are now versioned and deployed.
4. Define the full reversal/tombstone and append-only audit model for the remaining historical collections.
5. Service, SSH and storage hardening changes passed their separate reviewed plans; preserve their evidence and rollback artifacts.
6. Address token storage, Android backup policy, concurrency/idempotency and server-side invariant enforcement in small reviewed changes.

