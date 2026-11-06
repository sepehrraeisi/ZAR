# ZAR+ Transactional Restore Local Evidence — 2026-11-03

Status: supporting local evidence only. This document does not authorize a
production deployment and does not claim that the installed Android APK
contains these changes.

## Candidate boundary

- Branch: `codex/stabilization-baseline`.
- Candidate implementation commit: `31eadf7`.
- Draft PR: `#3`; it must remain unmerged without an explicit owner decision.
- PocketBase under test: `0.40.4`.
- Candidate assets: migration `1793604800_transactional_restore.js`, helper
  hook `zar_restore.js`, route hook `zar_restore_routes.pb.js`, explicit
  service hook arguments and `--hooksWatch=false`.
- Production was queried read-only only; no candidate file, setting, service
  unit or data was installed or changed.

## Local code and behavior gates

- PocketBase authorization suite: pass, including immutable workspace
  membership and append-only cash history.
- PocketBase migration-lineage suite: pass for fresh and existing-developer
  histories, including the exact 13-rule candidate state.
- PocketBase transactional-restore suite: pass. Covered password step-up,
  single-member authorization, all-seven-collection atomic replacement,
  cash restore, state-hash conflict, idempotent replay, request-ID misuse,
  rollback on ID collision, case-insensitive duplicate IDs, malformed
  references/reminders/cash openings, receipt privacy, shared-workspace denial,
  isolated restart/recovery and refusal to migrate down after a receipt.
- Exact local Flutter suite: **345 tests passed**, zero failures.
- Targeted restore/UI suite after the security remediation: **20 tests
  passed**, zero failures.
- `flutter analyze --no-pub`: no findings.
- Python syntax checks and `git diff --check`: pass.

## Independent security review

The review found one high-severity issue: after an ambiguous first commit, a
4xx response to the same-ID retry could be mapped to a definite failure even
though the first request might already be durable. The client now treats every
post-ambiguity result as unknown unless a complete receipt is verified.
Regression coverage includes HTTP `400`, `401`, `403`, `404`, `409`, `413`,
`422`, `428`, `429`, a second ambiguous result and an invalid replay receipt.
At this historical checkpoint a fresh independent follow-up review remained a
release gate. The later exact-tree operational review/remediation and closure
audit are recorded below; installed-APK proof remains separate.

## Receipt/hook-aware recovery evidence

The verifier was rerun after the final server-hook optimization against the
historical production-derived consistent database used by the 2026-10-30
recovery exercise.

- Source database SHA-256:
  `1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8`.
- Candidate migration SHA-256:
  `9c831f779bba098aab28cc4e1de09d6f84e6abb2a0b22e8f3ba74f2cf741ccd5`.
- Helper hook SHA-256:
  `55a08272eb0866ceb603466fed21014745a26494fd9ee6a782d2d10c2381f8b5`.
- Route hook SHA-256:
  `01aa50f90cef4212891f970487dde716e6b7d7fc1f3f6510678029ecb9d4f7c1`.
- Machine-readable local report:
  `work/transactional-restore-local-20261103/restore-report.json` (outside the
  repository because it derives from a production recovery set).
- Report SHA-256:
  `a4fd35398924b668406ef6ea44e165f6fced552c6cf60ab2e23e4f909c1c0a59`.
- Result: `pass`; source hash unchanged; service health passed; both hook files
  matched; receipt collection existed after migration with zero receipts and a
  canonical empty metadata hash; all eight domain tables reconciled; quick,
  integrity and foreign-key checks passed.

This snapshot predates the live rate-limit deployment and moved from four to
13 rules. It proves verifier behavior and historical data preservation, but it
does **not** prove the required current-production `11` to `13` delta, installed
systemd boundary, receipt replay after a real commit or both rollback branches.

## Read-only production check

At `2026-11-03T12:36:42Z`:

- `zar-server` was active and loopback `/api/health` returned `200`.
- `/api/zar/restore/state` returned `404`.
- Candidate migration and both hook files were absent.
- The installed service had no candidate hook-directory/hot-reload arguments.
- Rate limiting was enabled with exactly **11** rules.

Therefore production remained on the previously reviewed containment state.

## Remaining deployment blockers

1. Fresh independent security review of the ambiguity remediation.
2. Exact-head GitHub CI after publishing this candidate.
3. A fresh, consistent current-production snapshot clone rehearsal proving the
   exact `11`→`13` delta, service-stopped migration-before-hook order, real
   receipt replay/recovery and pre-/post-receipt rollback behavior.
4. Dedicated no-defaults guarded deploy and rollback tooling for this specific
   migration; the older rate-limit rollback path must fail closed.
5. Installed Android APK identity/signature and client behavior verification
   before any client release.
6. Replacement of the accepted same-host backup exception before customer data
   or launch.

## Later gate update

Items 3 and 4 above were closed by the fresh current-production clone rehearsal
and dedicated guarded deploy/rollback/containment tooling on 2026-11-05. See
`TRANSACTIONAL-RESTORE-CLONE-EVIDENCE-2026-11-05.md`.

The accepted final run is `0004`, not the earlier superseded rehearsals. Two
operational security-review rounds closed privileged input/evidence trust,
failure-file symlink writes, containment arming/recovery, unvalidated-state
restart, non-rate-settings drift and disposable-canary path/production-alias
boundaries. Independent closure audits additionally closed cross-name database
hardlinks, receipt-safe recovery gating, rollback restart/artifact fail-open
paths and asynchronous harness cleanup/readiness races; no blocking finding
remained.

Run `0004` retained `311` sanitized evidence files (`2.3 MiB`) under
`/root/zar-transactional-restore-clone-20261105-0004`. Its local `365`-entry
archive has SHA-256
`a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`
and no symlink, database, private-state or unsafe path. Production pre/post
sanitized hashes were both
`de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`;
the candidate remained absent from production. The final local tooling suite
ran `24` tests (`22` passed and two were expected skips), the real commit → restart → replay
test and all three PocketBase suites.

Items 1, 3 and 4 are therefore closed for the reviewed local bytes. Item 2
(exact committed-head CI), item 5 (installed Android identity/behavior) and
item 6 (replacement of the temporary same-host backup exception) remain
separate gates. Production is still unchanged and this evidence does not
authorize deployment.
