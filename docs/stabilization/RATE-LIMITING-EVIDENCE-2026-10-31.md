# ZAR+ Rate-Limiting Canary Evidence — 2026-10-31

Status: all documented policy-behavior, migration, batch, Real-IP,
natural-window and exact guarded rollback-path gates passed on isolated clones.
Production remained unchanged with
`rateLimits.enabled=false`; this document is pre-deployment evidence, not a
production completion record.

## Scope

The candidate is migration `1793437200_enable_rate_limits.js` and the policy in
`RATE-LIMITING-PLAN.md`. It is specific to PocketBase 0.40.4.

The tests used disposable SQLite online-backup copies of the live production
database. Every clone bound only to loopback on an isolated port. Synthetic
users, workspaces, records, credentials and tokens existed only inside those
clones, were not printed into evidence and were deleted with the unencrypted
clone directories after each run.

No candidate file was placed in the production migration directory and no
candidate history row was added to production.

## Migration round trip

The candidate refused silent policy inheritance by requiring the complete
reviewed disabled baseline. On an isolated clone:

- `migrate up` installed the exact 11-rule policy, `excludedIPs=[]` and
  `enabled=true`;
- history gained exactly `1793437200_enable_rate_limits.js`;
- `migrate down 1` removed exactly that row and restored the byte-identical
  baseline rate-limit JSON with `enabled=false`;
- pre-change, stopped-state and post-rollback domain counts were identical;
- `quick_check` and `integrity_check` returned `ok`.

The up/down bodies also refuse to overwrite a settings object that has drifted
from their exact expected state.

## Main behavior canary

Evidence directory: `/root/zar-rate-limit-canary-20261031T093500Z`.

The clone used the same baseline domain counts as production:

```text
zar_workspaces=1
zar_people=1
zar_deals=0
zar_settlements=1
zar_coin_types=0
zar_currency_types=0
zar_allocations=0
zar_cash_entries=0
```

Every intended boundary passed:

- authentication: attempts 1–5 returned the normal `400`; attempt 6 returned
  `429`;
- a distinct synthetic client IP remained independent and returned `400`;
- signup: five validation responses, then `429`;
- password reset, OTP, verification and email-change request classes: three
  normal endpoint responses, then `429`;
- the three confirmation classes: ten normal validation responses, then `429`;
- unauthenticated API fallback: 60 health responses returned `200`; request 61
  returned `429`;
- 61 authenticated health requests from one IP all returned `200`, proving the
  guest fallback does not throttle signed-in traffic;
- authenticated outer batch: ten requests reached normal validation and the
  eleventh returned `429` in one fixed window.

The real transaction probes also passed:

- one 500-create same-collection batch returned `200` in `791 ms` and exactly
  500 rows reconciled;
- two sequential 400-create same-route authenticated chunks returned `200` in
  `633 ms` and `625 ms`; exact final count was 1,300;
- a deliberately invalid two-item batch returned `400`, its first valid create
  was absent (`404`) afterward, and atomic rollback was therefore proven;
- SQLite quick/integrity checks remained `ok`.

Machine-readable HTTP evidence SHA-256:
`e70967f8c3f54cf996aa6cc94667914c9ca284b6d2f62c2f21366523f59c8558`.

## Real-IP and superuser canary

Successful evidence directory:
`/root/zar-rate-limit-proxy-test-20261031T091500Z`.

- Twelve rate-matched auth requests carrying an authenticated clone-only
  superuser token received normal `400` validation responses and never `429`.
- Without a token, the same superuser authentication class returned five
  normal invalid-credential responses and `429` on request six.
- A loopback-only disposable Caddy instance used the same private header
  overwrite as production. Five requests supplied five different forged
  `X-Zar-Client-IP` values but returned normal `400`; request six with a sixth
  forged value returned `429`. The upstream therefore saw one Caddy-overwritten
  real source bucket, not attacker-controlled buckets.
- Clone integrity remained `ok`; migration down passed and the clone was
  deleted.

The first complementary attempt at
`/root/zar-rate-limit-proxy-test-20261031T091000Z` was stopped because the
disposable Caddy tried to use production Caddy's admin port `127.0.0.1:2019`.
It never changed the live Caddy or PocketBase configuration. Its clone and
credentials were deleted. The fixture was corrected with `admin off`, validated
and the complete test passed in the separate successful directory above.

## Natural expiry, startup burst and log canary

Evidence directory: `/root/zar-rate-limit-expiry-test-20261031T092000Z`.

- The same synthetic IP received five normal auth responses, then `429`.
- Without a service restart or settings reload, the window was observed limited
  at `2026-10-31T14:00:05Z`; after 62 seconds it returned the normal `400` at
  `2026-10-31T14:01:07Z`.
- Eleven concurrent authenticated batch probes produced exactly ten normal
  validation responses and one `429`; after two seconds the next request again
  received the normal `400`.
- Session restore/user lookup returned `200`.
- Two simultaneous seven-collection snapshot bursts produced exactly 14 HTTP
  `200` responses with no `429`.
- The bounded clone log interval contained zero error-level events and zero
  HTTP status values at or above 500.
- Clone quick/integrity checks returned `ok`; migration down passed and the
  clone was deleted.

## Exact guarded rollback rehearsal

The production-shaped rollback path is versioned in
`server/scripts/guarded_rate_limit_rollback.sh`; its disposable-clone harness is
`server/scripts/test_guarded_rate_limit_rollback_clone.sh`. The final script
has SHA-256
`7299707a0faaeb39627aeccd1eac49e55b8147803b13ae731e6ea5dee76821e7`
and passed `bash -n` plus a complete execution in
`/root/zar-rate-limit-rollback-clone-20261031T153500Z`.

The rehearsal used SQLite online backups of both production `data.db` and
`auxiliary.db`, bound the disposable PocketBase service to loopback and ran the
same no-defaults script intended for production. It proved:

- exact PocketBase binary, migration and settings hashes plus
  service-to-database paths were guarded;
- the candidate was latest and present exactly once before stop;
- settings, history, file hash and domain counts were rechecked after stop;
- explicit `migrate down 1`, removal of only the candidate file and
  start-to-health succeeded;
- migration filename history, stopped-state/post-rollback domain counts,
  restart counter and byte-identical baseline settings reconciled;
- main and auxiliary quick/integrity checks returned `ok`, the bounded error
  journal was empty and the unencrypted clone was deleted;
- production retained candidate history count `0` and no candidate file.

Three earlier rehearsals failed closed and are retained as negative evidence.
They exposed missing quiet journal handling, stronger service/path binding and
an incomplete clone that omitted `auxiliary.db`. PocketBase 0.40.4 legitimately
reapplied its auxiliary initializer in that incomplete clone; no production
corruption occurred. After copying both databases and using PocketBase's
official migration ordering expression, four complete rehearsals passed, with
the final run above covering the exact versioned script.

## Production non-change proof

After all canaries:

- Caddy, PocketBase and `zar-backup.timer` were active;
- internal and public health returned `200`;
- production candidate migration history count was `0`;
- production rate limits still contained the four original disabled rules and
  `excludedIPs=[]`;
- no candidate file existed in `/opt/zar/server/pb_migrations`;
- the production main database file SHA-256 recorded before and after the main
  canary was unchanged:
  `69305a6cab4d5ff0570fec2eeae20a86d16aa3eafb18271ccf49427038c711c9`.

The file hash is supporting evidence, not a substitute for SQLite consistency
in a WAL database; the canaries were sourced with SQLite's online backup API
and also used logical counts plus quick/integrity checks.

## Client and repository checks

- The PocketBase auth service now maps HTTP 429 to a clear Persian message for
  sign-in, signup and password reset; it does not automatically retry a
  financial or auth request.
- Three focused 429 tests and the existing PocketBase repository tests passed.
- Full local Flutter suite after this candidate: **331 passed, zero failed**.
- Full `flutter analyze`: no issues.
- GitHub Actions run #254 at `1c3fb7b` passed both `flutter-checks` and
  `pocketbase-authorization`; the final rollback-script/documentation commit
  still requires its own exact-head CI before production.
- The Persian message is candidate source behavior only. It is not present on
  an already-installed older APK until a reviewed build is installed.
- The destructive canary tool now requires
  `--confirm-disposable-clone` and rejects every non-loopback base URL before
  creating data. A deliberate production-URL invocation was refused and wrote
  no evidence file.

## Archived evidence

The superseding complete archive contains the main canary, the documented
aborted Caddy attempt, the successful proxy/superuser and natural-expiry runs,
all fail-closed rollback rehearsals and the final exact-script passing run.

Local path:

```text
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-canary-20261031\zar-rate-limit-evidence-complete-v5-20261031.tar
```

SHA-256:
`90ba7772e4bb02493f70729479e769a426458d21eca7743adc03cadcd528910c`.

The temporary transferable archive on the server was removed after local hash
verification. Root-only source evidence directories remain on the server for
the production preflight and rollback record.

## Remaining production gates

Production must not change until all of these are complete:

1. commit and push the exact final candidate, then obtain green GitHub CI at
   that exact commit;
2. capture a fresh verified backup and exact pre-change settings, migration,
   rules, counts, restart, route and bounded-log evidence;
3. pin the production evidence-directory, migration and rollback-script hashes
   and exact no-defaults invocation;
4. capture before/after public smoke matrices without intentionally exhausting
   a real production IP bucket;
5. deploy only the versioned migration, then observe minute 0, 5 and 15 health,
   restart, 429 and 5xx evidence;
6. record separately whether the installed Android APK contains the new Persian
   429 message; server deployment alone must not claim that client release.

Public signup intent, per-account failed-attempt controls, distributed attack
protection and external alert delivery remain separate open decisions.
