# ZAR+ Rate-Limiting Production Evidence — 2026-11-01

Status: **server production gate passed**. The exact reviewed PocketBase
rate-limit policy was deployed through the guarded path and remained healthy
through the minute 0, 5 and 15 observations. Rollback was not required.

This is a server deployment record. It does not prove that the APK currently
installed on the owner's phone contains the new Persian HTTP 429 message;
installed-APK sign-in/startup verification remains a separate release gate.

## Scope and exact artifacts

- Exact CI head: `8c060542a88b37b26ff1637ea9c56fde1bf4460b`.
- GitHub Actions: run #257, ID `41343818686`; `flutter-checks` and
  `pocketbase-authorization` both passed at that exact head.
- Production evidence directory:
  `/root/zar-rate-limit-production-20261101T195200Z`.
- Deployment start: `2026-11-01T19:55:20Z`.
- Migration: `server/pb_migrations/1793437200_enable_rate_limits.js`, SHA-256
  `6dfe631f6e1e65e68060c753f23b700ddc51488623987b6cfc110ebb40af89f2`.
- Guarded deploy script SHA-256:
  `4a8701502d846e875e216193bba5a948d40777819987b4db36a23f7c8a0cfbde`.
- Guarded rollback script SHA-256:
  `788ec9d23d62fa6a2ef81f0cb83606b888be09fdde916ee4a219ba821a1072dd`.
- PocketBase 0.40.4 binary SHA-256:
  `14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a`.

The guarded scripts have no implicit production target. Their exact
deploy/recovery/rollback behavior, including both forced recovery branches,
had already passed against a full two-database production clone before this
window.

## Preflight and recovery point

The preflight required the live migration history, complete disabled
rate-limit object, collection rules, domain counts, database integrity,
service/restart state and route matrix to match the reviewed baseline. It also
required internal and both public health endpoints to return HTTP 200 and the
public PocketBase dashboard to remain denied.

Fresh recovery point:

```text
/backups/zar-daily/zar-20261101T195240Z/data.db
SHA-256 c9c420d10960a63e86173c1be28f73efa3d4e8122bce07c12eda9be12499e2be
```

The snapshot checksum, SQLite `quick_check` and `integrity_check` passed. The
live and backup migration/settings/count state matched before deployment.

## Production change result

The guarded deploy kept the candidate outside the live migration directory
until stopped-state verification, installed only the pinned migration, ran an
explicit migration-up as `zarapp`, and required bounded restart-to-health. It
reported `RATE_LIMIT_DEPLOY_PASS`.

Production migration history gained exactly one row:

```text
1793437200_enable_rate_limits.js|1793562921723345
```

The installed migration hash matched the reviewed source. The complete live
settings object contains the exact 11 ordered rules, `excludedIPs=[]` and
`enabled=true`:

- `*:auth`, all audiences: 5 requests per 60 seconds;
- `users:create`, all audiences: 5 per 600 seconds;
- password-reset, OTP, verification and email-change requests: 3 per 300
  seconds for each action;
- password-reset, verification and email-change confirmations: 10 per 300
  seconds for each action;
- outer `/api/batch`, authenticated audience only: 10 per second;
- `/api/` fallback, guest audience only: 60 per 10 seconds.

There is no wildcard create rule and no generic authenticated API rule.

## Observation result

The common service, settings, history, count, integrity and bounded-log
acceptance set passed at minute 0, 5 and 15, and the final aggregate result was
`RATE_LIMIT_PRODUCTION_OBSERVATION_PASS`. The full before/after normal-route
status and body-class matrix was captured and matched at minute 0 only:

- `zar-server.service`, Caddy and the backup timer remained active;
- PocketBase `NRestarts` remained `0`;
- internal health and both public health URLs returned HTTP 200;
- the dashboard/management surface stayed HTTP 404 on both public hosts;
- the expected invalid-auth and invalid-batch probes remained HTTP 400;
- domain counts and migration history remained at their exact expected values;
- both SQLite databases retained successful integrity results;
- bounded service journals contained no new deployment error;
- PocketBase request evidence since deployment contained no HTTP 429 and no
  status greater than or equal to 500.

Only low-rate smoke probes were sent. Full authentication, guest and batch
boundaries were deliberately not exhausted from a real production IP; those
boundaries remain proven by the archived disposable-clone evidence.

## Rollback status

Rollback was prepared but not required. The exact rollback remains guarded by
the expected migration position/history, deployed policy and archived
pre-change state. Its migration-down and full service/count/integrity/log path
was exercised only on disposable production clones; no production rollback
was executed because every production gate passed.

## Archived evidence

The production evidence archive is stored off the server at:

```text
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-production-20261101\zar-rate-limit-production-evidence-20261101.tar
```

SHA-256:
`7877588bbee36233c854fa45b7dfa761eb7252179f4166d1313b7efc697adc95`.

The archive contains 81 entries and its internal hash manifest passed. It is
operational evidence, not an independent disaster-recovery destination and
does not close the temporary same-host backup exception.

## Remaining release and operational gates

- Inspect the APK installed on the owner's phone and prove its package,
  version, signing identity, sign-in/startup behavior and Persian 429 message.
- Do not claim the client-side Persian UX is deployed until that APK gate
  passes.
- Add an external alert destination for sustained 429/5xx, service health,
  restart and backup-age events.
- Decide and enforce the intended public-signup policy.
- Repeat the route-label, batch and Real-IP review before any PocketBase or
  proxy topology upgrade.
