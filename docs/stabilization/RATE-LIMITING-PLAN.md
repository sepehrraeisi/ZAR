# ZAR+ PocketBase Rate-Limiting Plan

Status: all isolated-clone behavior, natural-expiry, Real-IP, superuser and
migration round-trip gates passed on 2026-10-31. Production is unchanged until
the remaining exact-commit CI and guarded production rollback gates pass. See
`RATE-LIMITING-EVIDENCE-2026-10-31.md`.

## Objective

Reduce credential guessing, public-account abuse, mail-trigger abuse and
accidental request storms without interrupting normal startup, accounting
writes or the supported atomic backup restore path.

This change is scoped to PocketBase 0.40.4. Any PocketBase upgrade must repeat
the route-label and batch behavior review before retaining these limits.

## Why the disabled defaults are unsafe

The production baseline contains four disabled rules:

- `*:auth`: 2 requests per 3 seconds;
- `*:create`: 20 requests per 5 seconds;
- `/api/batch`: 3 requests per second;
- `/api/`: 300 requests per 10 seconds.

PocketBase executes collection rate checks for each internal `/api/batch`
subrequest. ZAR permits a 500-operation atomic restore and sends allocation
updates in sequential 400-operation chunks. Therefore merely changing
`enabled` to true would make a transaction fail after 20 same-collection
creates or 300 fallback-matched operations. The client does not automatically
retry HTTP 429, and a generic automatic retry would not be safe for financial
writes until idempotency is proven.

Normal legitimate bursts also include seven concurrent collection reads for a
complete snapshot and, when an automatic backup is due, a second snapshot soon
after startup.

## Reviewed phase-one policy

Migration `1793437200_enable_rate_limits.js` replaces the disabled defaults
with these exact rules and keeps `excludedIPs` empty:

- any authentication method: 5 requests per 60 seconds per real client IP;
- public `users` record creation: 5 requests per 600 seconds;
- password-reset, OTP, verification and email-change requests: 3 requests per
  300 seconds for each action;
- password-reset, verification and email-change confirmations: 10 requests per
  300 seconds for each action;
- authenticated outer `/api/batch` calls: 10 requests per second;
- all other unauthenticated `/api/` traffic: 60 requests per 10 seconds.

There is deliberately no wildcard `*:create` rule and no authenticated generic
`/api/` rule in phase one. Sensitive exact labels take precedence over the
guest fallback. Authenticated batch subrequests therefore do not consume the
guest bucket, while the outer batch request has its own limit.

The migration refuses to apply unless the entire prior rate-limit object still
matches the reviewed disabled baseline. Its down migration similarly refuses
to overwrite an intervening operator edit and restores the complete original
rules, `excludedIPs=[]` and `enabled=false`.

The candidate Android-facing auth service translates a 429 into an actionable
Persian message and does not automatically replay the request. This behavior is
not present on an already installed APK; building and installing a release that
contains the client commit is a separate gate before claiming the Persian UX is
deployed.

## Isolated-clone gates

The candidate must be tested only against a disposable copy of the production
database, bound to loopback on a separate port. No customer row, password,
token or email address may be printed into evidence.

The versioned probe refuses non-loopback URLs and requires the explicit
`--confirm-disposable-clone` acknowledgement. Never point it at production.

1. Record source snapshot checksum, migration history, settings hash, domain
   counts and SQLite quick/integrity results.
2. Apply only the candidate migration and verify the exact rule order, values,
   audiences, empty exclusion list and `enabled=true`.
3. With one synthetic external IP, prove five invalid auth attempts receive the
   normal invalid-credential response and the sixth receives 429. A second IP
   must retain its independent allowance. Without restarting or reloading
   settings, wait at least 61 seconds and prove the first IP again receives the
   normal invalid-credential response.
4. Prove the boundary for signup and each request/confirmation class without
   sending real mail or retaining test accounts.
5. Prove the first 60 guest health/API requests pass and request 61 receives
   429; an authenticated request must not consume that guest bucket.
6. Create a clone-only regular user and workspace. Submit a real 500-operation
   same-collection batch, reconcile exact record counts and run SQLite
   integrity checks. No nested operation may receive 429.
7. Submit multiple sequential 400-operation same-route authenticated chunks
   and prove they are not constrained by the guest fallback. Record whether
   PocketBase's existing three-second batch timeout is sufficient; timeout
   failure is a separate release blocker, not a reason to weaken evidence.
8. Inject one invalid item into a smaller mixed batch and prove the complete
   transaction rolls back.
9. Prove ten authenticated outer batch calls are accepted in one window and
   the eleventh receives 429.
10. Prove the trusted client-IP header separates synthetic client buckets and
    that a Caddy hop overwrites a forged incoming value.
11. Prove a loopback superuser token bypasses rate limiting, while pre-auth
    superuser login remains both rate limited and unavailable on the public
    Caddy surface.
12. Apply `migrate down 1`, verify the exact disabled baseline is restored,
    restart the clone, repeat a boundary probe showing no 429, and reconcile
    migration history, counts and SQLite integrity.
13. Delete the unencrypted disposable clone and any clone-only credentials
    after evidence is archived.

Cloud snapshot replacement has a pre-existing independent constraint: cash
journal update/delete is intentionally locked, while the current app restore
algorithm still attempts delete-and-recreate. A clone containing existing cash
rows must fail that path with authorization rollback, not be misclassified as
a rate-limit failure. A safe append-only/new-workspace restore design remains a
separate release blocker.

## Production preflight

- Latest application and authorization CI jobs pass at the exact candidate
  commit.
- The branch is clean and the candidate migration is the only expected server
  delta after the already deployed admin-containment migration.
- SSH, Caddy, PocketBase and the backup timer are active with no unexplained
  restarts or bounded-journal errors.
- Internal and both public health endpoints return 200.
- A fresh atomic backup passes checksum, schema and integrity validation.
- The isolated clone has passed every gate above, including migration down.
- The production settings, latest migration, collection rules, domain counts
  and database hashes match the captured expected pre-change state.

## Production change and post-change gates

1. Archive the exact pre-change settings and migration state in a root-only
   evidence directory.
2. Install only the reviewed migration with owner `zarapp:zarapp` and mode
   `0644`.
3. Restart PocketBase once so the migration applies before serving traffic;
   require bounded restart-to-health.
4. Verify exact settings and one expected migration-history addition.
5. Run only low-rate production smoke probes and never exhaust a bucket from an
   IP/NAT used by the real app. Full 429 boundaries and 11-request batch bursts
   belong exclusively in the disposable clone.
6. Exercise real Android sign-in and startup snapshot without changing
   production business rows.
7. Re-run public/admin route matrices, service state, restart counters, domain
   counts, SQLite checks and bounded logs.
8. Observe health, service/restart state, 429 and 5xx logs at minute 0, 5 and 15.
   Any unexplained 429 on normal app traffic requires rollback or a separately
   reviewed correction.

Production success requires all normal routes to retain their pre-change
status/body class, sensitive probes to hit the exact documented boundaries,
domain counts to remain unchanged and both database integrity checks to return
`ok`.

## Rollback

Keep Caddy's administrative filtering active. Stop PocketBase and refuse the
rollback unless:

- this candidate is still the latest migration;
- its history row exists exactly once;
- the full live rate-limit object equals the deployed policy;
- the archived pre-change settings and migration file hashes match evidence.

Run one explicit `migrate down 1` as `zarapp` with production `--dir` and
`--migrationsDir`, verify the exact disabled baseline, remove only the deployed
candidate file, then start PocketBase and repeat health, count, integrity,
migration, restart and log gates. If any guard fails, leave Caddy filtering in
place, restart PocketBase if it was stopped and investigate rather than editing
the database manually.

The exact production rollback script and evidence-directory hash will be added
only after a successful production preflight determines those immutable values.

## Residual risk

- PocketBase uses in-memory fixed windows; a boundary burst can approach twice
  the nominal rate and counters reset on restart or settings reload.
- Per-IP limits can inconvenience users behind one shared NAT and do not stop a
  distributed attack.
- Authenticated ordinary CRUD has no broad phase-one limiter. Add one only after
  traffic characterization and explicit client behavior for 429.
- Public signup remains a separate product decision; rate limiting does not
  decide whether signup should remain open.
- There is still no external alert destination for sustained 429/5xx events.
