# ZAR+ Transactional Restore Clone Evidence — 2026-11-05

Status: **PASS on a disposable current-production clone; production was not deployed or mutated.**

The final post-review rehearsal ran from `2026-11-05T13:54:06.738Z` to
`2026-11-05T13:58:03.970Z` (`2026-11-05 17:24–17:28` Asia/Tehran). It used
fresh SQLite `.backup` copies of the active production databases, an immutable
copy of the current migration directory, a unique loopback port and a unique
transient systemd unit. The live service remained active throughout.

## Frozen boundary

- Production source: `/opt/zar/server/pb_data/{data.db,auxiliary.db}` and
  `/opt/zar/server/pb_migrations`, read through SQLite backup/copy operations.
- Disposable service: `zar-restore-clone-20261105-0004.service`.
- Disposable listener: `127.0.0.1:18093`.
- Root-owned candidate staging:
  `/root/zar-restore-candidate-20261105-0004`.
- Evidence directory:
  `/root/zar-transactional-restore-clone-20261105-0004`.
- Expected-state manifest SHA-256:
  `3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3`.
- Canary SHA-256:
  `8e17b0973846da01c158f2960e9709594a1b3742fb39cf27b29a458d75c0f697`.
- PocketBase remained the already verified `v0.40.4` binary with SHA-256
  `14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a`.

All root-executed inputs were regular non-symlink files owned by `root:root`
and not group/world writable. The harness accepted only the exact production
read boundary, a fresh `/root/zar-transactional-restore-clone-*` evidence path,
a `/opt/zar/server/restore-clone.*` work tree, a unique clone unit and a
non-`8090` loopback port.

## Guarded tooling exercised

- `server/scripts/guarded_transactional_restore_deploy.sh`
- `server/scripts/guarded_transactional_restore_rollback.sh`
- `server/scripts/guarded_transactional_restore_contain.sh`
- `server/scripts/test_guarded_transactional_restore_clone.sh`
- `server/scripts/transactional_restore_state.py`
- `server/scripts/transactional_restore_state_guard.py`
- `server/scripts/transactional_restore_canary.py`
- `server/scripts/transactional_restore_expected_state.json`
- `server/deploy/zar-server-transactional-restore.conf`

The state evidence is deterministic and payload-free. It contains integrity
results, ordered migration names/hashes, exact rate policy, collection/schema
fingerprints, domain counts/content hashes and receipt metadata hashes; it does
not contain financial rows, user identifiers, passwords, bearer tokens or
restore request bodies.

## Security-review and closure history

The earlier rehearsals were deliberately superseded rather than accepted as
final. The first dedicated review found four issues:

- privileged-input trust did not cover every parent and runtime artifact;
- containment failure recovery could restore a route or restart an unverified
  service;
- canary confirmation did not bind strongly enough to a disposable clone and
  reject the production listener;
- non-rate-limit PocketBase settings were not included in deterministic drift
  detection.

Those issues were remediated with root-owned parent-chain validation, pinned
runtime hashes, fail-closed containment, explicit clone/systemd/listener
identity, rejection of port `8090`, and a canonical hash for all non-rate-limit
settings.

The permitted follow-up review found four additional boundary problems:

- ERR traps could write through a pre-existing evidence-file symlink before
  the evidence directory was trusted;
- containment was armed only after the first stop checks;
- deploy recovery could restart on an unknown or unvalidated database state;
- the canary's lexical clone-path check could be bypassed with traversal,
  symlink or production-database aliasing.

The final tooling validates an empty root-owned `0700` evidence directory and
every parent before installing traps, pins its device/inode through an open file
descriptor, and creates failure files with no-follow/exclusive semantics.
Containment and rollback are armed before their first stop attempt. Unknown
deploy state quarantines an exact route but remains stopped; only a validated
`contained` profile with a positive receipt and exact artifacts may restart.
Canary identity resolves the executable/data/migrations/hooks tree strictly,
rejects symlinks and traversal, and compares both clone database inodes against
the complete set of both production database inodes and against each other.

Independent read-only closure audits then caught and drove fixes for cross-name
database hardlinks, rollback restart/artifact fail-open paths, an over-strict
baseline comparison in receipt-bearing recovery, asynchronous-test cleanup and
readiness races. Their final pass found no remaining blocking issue in these
boundaries. This is closure evidence for the candidate tooling, not
authorization to deploy it.

## Rehearsal matrix and result

Every case started from a new copy of the same production snapshot:

1. Six forced deploy failures covered migration install, migrate-up, helper
   install, route install, unit-overlay install and unhealthy start. Each
   recovered only through its allowed baseline or guarded-down path.
2. An intentionally unavailable recovery-state proof quarantined the exact
   route and kept the service/listener stopped; it did not restart on health
   alone or run migrate-down.
3. Deploy, rollback and containment each rejected a pre-existing failure-file
   symlink without changing its sentinel target, service PID or activation
   timestamp.
4. All three entry points rejected a root-owned `0700` evidence directory below
   a world-writable parent without stopping or restarting the service.
5. A byte-identical privileged input below an untrusted parent was rejected
   before mutation, with the service PID and activation timestamp unchanged.
6. A clean deployment changed the exact rate policy from 11 to 13 rules; normal
   pre-receipt rollback restored migration history and the exact 11-rule policy
   while retaining the intended workspace-membership lock.
7. Rollback recovery was exercised at the pre-stop boundary, with a forced
   unhealthy recovery start, and after rollback start. It restarted only exact
   deployed/rolled-back state and otherwise forced the service/listener down.
8. Containment failures both before the first stop and after contained start
   left the exact route quarantined and the service/listener stopped without
   changing sanitized database state.
9. The ambiguous-outcome branch with zero visible receipts quarantined only the
   route and preserved migration, helper, schema, settings and domain state.
10. A real committed receipt was introduced while guarded deploy waited at an
    explicit post-guard readiness boundary. Deploy recovery accepted only the
    receipt-bearing contained profile, quarantined the route and restarted
    healthy with both restore endpoints returning `404`.
11. A separate real seven-collection restore including cash committed
    atomically, survived a real systemd restart and replayed the identical
    private receipt.
12. Wrapper rollback after a receipt refused with exit code `78` without
    changing service, artifacts or sanitized database state.
13. Raw `migrate down 1` also refused after a receipt and made no state change.
14. Receipt-present containment removed only the route, retained the helper,
    migration, receipt and 13-rule state, restarted healthy and returned `404`
    for both restore endpoints.

The final result file records:

```text
status=pass
production_candidate_file=absent
production_candidate_history=0
production_rate_rules=11
deployed_rate_rules=13
failpoints=6
nonempty_evidence_refusal=pass
evidence_symlink_refusal_all_entrypoints=pass
untrusted_evidence_parent_refusal_all_entrypoints=pass
untrusted_input_refusal=pass
unvalidated_recovery_stays_stopped=pass
deploy_receipt_recovery=pass
pre_receipt_rollback=pass
rollback_failure_recovery=pass
containment_pre_stop_failure_fail_closed=pass
containment_failure_fail_closed=pass
ambiguous_forward_only_containment=pass
receipt_restart_replay=pass
receipt_rollback_refusal=pass
receipt_raw_down_refusal=pass
forward_only_containment=pass
private_canary_state=deleted
```

## Evidence custody and privacy

- Remote evidence: `/root/zar-transactional-restore-clone-20261105-0004`
  (`311` files, approximately `2.3 MiB`).
- Local sanitized archive:
  `C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\transactional-restore-clone-20261105-0004\zar-transactional-restore-clone-20261105-0004.tar.gz`.
- Archive SHA-256:
  `a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`.
- Archive inspection: `365` entries including directories; zero symlinks,
  unsafe paths, SQLite/database files and private-canary-state entries.
- All `164` JSON entries were scanned for password, token, authorization,
  request-body and synthetic canary-identity material; zero matches were found.
- Both private canary state files were `root:root 0600` inside their disposable
  clone trees, were used only for commit/replay or receipt-recovery proof, and
  were deleted before final evidence capture.

## Production postflight

Immediately after cleanup:

- `zar-server.service` and Caddy were active; loopback health passed.
- `/api/zar/restore/state` returned `404`.
- Candidate migration, helper, route and `20-transactional-restore.conf` were
  absent from all production paths.
- Candidate migration history count was `0`; exact production rate-rule count
  remained `11`.
- The clone unit/drop-in, listener and `/opt/zar/server/restore-clone.*` work
  tree were absent.
- Sanitized production preflight and postflight state SHA-256 values were both
  `de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`.

Therefore the clone rehearsal did not change production state.

## Local verification after the rehearsal

- Deterministic state/guard/canary/manifest suite: `24` tests ran; `22` passed
  and `2` were expected platform/environment skips.
- The skipped real PocketBase commit → restart → replay test was run separately
  against PocketBase `v0.40.4` and passed.
- PocketBase authorization suite: pass.
- PocketBase migration-lineage suite: pass.
- PocketBase transactional-restore suite: pass.
- Python compilation, shell syntax and Git whitespace checks: pass.

## Remaining gates

This evidence closes the fresh current-production `11`→`13` clone-rehearsal,
guarded-tooling and independent closure-audit blockers. It does **not** authorize
production deploy. The exact committed head must still pass Draft PR CI; then
the owner must make a separate explicit production-change decision with a fresh
backup/recovery set, named operator/rollback owner and maintenance window. The
installed Android APK and the temporary same-host disaster-recovery exception
remain separate open release gates.
