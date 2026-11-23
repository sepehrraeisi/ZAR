# AGENTS.md — ZAR+ agent onboarding (Cursor / Claude / any coding agent)

> این سند نقطه‌ی شروع هر ایجنت هوش مصنوعی در این ریپوست. عمق کامل: `docs/stabilization/PROGRAMMER-HANDOFF.md` (فارسی). قبل از هر تغییر سخت‌گیرانه، بخش "Hard rules" را بخوان.

ZAR+ is an **operational gold & currency shop app** for Iranian shopkeepers:
Flutter (Android, Persian/RTL, Material 3) + a self-hosted PocketBase backend.
It tracks customers, buy/sell deals (gold/USD/AED/coins), pending settlements
with reminders, and a physical cashbox. It is deliberately **NOT a general
accounting/GL system** — no ledger/tax/P&L features until the owner + a
specialist accountant sign off.

Owner & product decisions live with **sepehrraeisi** (GitHub) — this repo is
public. Everything below assumes you are an AI agent working on this repo.

## 0. Hard rules (read first, never skip)

1. **No secrets anywhere**: repo/PRs/commits/docs/issues must never contain
   passwords, tokens, private keys, customer data or DB files. CI enforces
   this (GitGuardian + gitleaks + a hidden-character scan). Do not read or
   print `~/.ssh/**`, `~/.aws/**`, `*.jks`, `*.keystore`, `.env*`,
   `**/*credentials*.txt` — deny rules block these for agents on purpose.
2. **`master` is protected**: no direct pushes. Every change = branch → CI
   green → PR → merge. Required checks: `flutter-checks`,
   `pocketbase-authorization`, `secrets-scan`, `dependency-sbom`.
3. **Production discipline**: never mutate the production server without
   (a) a fresh atomic backup (`sudo /usr/local/sbin/zar-backup`), (b) the
   off-site pull verified, (c) a rollback path, (d) the owner's ok. Only
   versioned migrations — never edit an applied one.
4. **Migration lineage**: `1793604800_transactional_restore.js` is the lineage
   top. After the first restore receipt, **down-migrations below it are
   forbidden (forward-only)**. New migrations must be numbered **below** it
   (e.g. `17936047xx`) — the transactional restore test assumes it stays last.
5. **PocketBase listener is loopback-only (127.0.0.1:8090), always.** Never
   expose it. The VPS also hosts shared DNS (BIND9) and mail (Postfix) for
   other things — do not touch them.
6. **Financial scope**: integer minor units + decimal strings for amounts, no
   floats; money domain rules are validated by tests; no accounting features
   without the accountant sign-off above.

## 1. Repo map

```
lib/                 Flutter app (Persian/RTL, Material 3)
  features/          auth, theme (ZarTheme = design tokens), backup, cashbox,
                     inventory, notifications, people …
  data/              domain models + zar_domain_backup_codec.dart (backup V8
                     JSON shapes = the cloud payload shapes) +
                     data/pocketbase/ (client, repository)
  repository_phase_a2_app_v2.dart   production shell wiring
server/
  pb_migrations/     versioned PocketBase migrations (collections + rules)
  pb_hooks/          zar_restore.js / zar_restore_routes.pb.js (transactional
                     cloud restore: CAS + idempotency receipts)
  deploy/            systemd unit overlays (containment, transactional restore)
  scripts/           guarded deploy/rollback/containment/clone-rehearsal +
                     transactional_restore_state*.py, canary, expected_state
  tools/             zar_backup source, zar_health_check.sh, off-site pull
  tests/             python suites run against a real PocketBase binary
test/                349 Flutter tests (widget + domain)
docs/stabilization/  the deep docs (handoff, roadmap, runbooks, evidence)
DESIGN.md            the design system — read it before ANY UI change
.github/workflows/   phase_a2_ci.yml + supply_chain.yml (Actions are SHA-pinned)
```

## 2. Commands

Client (from repo root):

```bash
flutter pub get
flutter analyze --no-fatal-infos      # must be clean
flutter test                          # 349 tests, must be green
flutter build apk --release --split-per-abi --target-platform android-arm64 \
  --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=<N+1>
```

Server invariant suites (need a PocketBase 0.40.4 binary; CI downloads it):

```bash
python3 server/tests/pocketbase_authz_test.py --pocketbase <binary>
python3 server/tests/pocketbase_domain_hard_delete_test.py --pocketbase <binary>
python3 server/tests/pocketbase_transactional_restore_test.py --pocketbase <binary>
python3 server/tests/pocketbase_migration_lineage_test.py --pocketbase <binary>
```

## 3. Data model (what the backend stores)

Seven collections, all rows `{id, workspace, data:<domain JSON>}` — the
`data` payload shapes come from `ZarDomainBackupCodec` (`lib/data/zar_domain_backup_codec.dart`):
`zar_people`, `zar_deals`, `zar_settlements`, `zar_allocations`,
`zar_coin_types`, `zar_currency_types`, `zar_cash_entries`, plus
`zar_workspaces` (members list) and `zar_restore_receipts`.

Enum names that matter (wrong names fail decode → workspace won't load):
- deal `type`: `buy` / `sell`; deal `status`: `active` / `completed` / `cancelled`
- settlement `direction`: **`receive` / `deliver`** (NOT "pay")
- settlement `status`: **`open` / `completed` / `cancelled`** (NOT "pending")
- amounts: `{assetType:'currency', currency:{code, minorUnits, minorUnitScale}}`
  or `{assetType:'gold', gold:{decimal, unit, purity}}`; toman pricing uses
  `{wholeTomans: int}`.

Invariants already enforced server-side: workspace-scoped reads/writes, cash
append-only, workspace deletion locked, workspace membership immutable via
Record API, hard-delete denied on people/deals/settlements/coin/currency
types (reversal semantics instead), transactional restore with CAS +
idempotency receipts, ordinary people/deals/settlements upserts via
`/api/zar/write/upsert` (revision CAS + write receipts; evidence
`CLOUD-WRITE-CAS-EVIDENCE-2026-11-23.md` — deployed to production
2026-11-23). Coin/currency CAS deployed (`1793604695`, evidence
`CLOUD-WRITE-CAS-CATALOG-EVIDENCE-2026-11-23.md`). Allocation replace CAS
deployed (`1793604698`, evidence
`ALLOCATION-REPLACE-CAS-EVIDENCE-2026-11-23.md`). Atomic workspace bootstrap
deployed (`1793604699`, evidence
`WORKSPACE-BOOTSTRAP-EVIDENCE-2026-11-23.md`). Cash append CAS deployed
(`1793604701`, evidence `CASH-APPEND-CAS-EVIDENCE-2026-11-23.md`). Open:
signup launch policy + abuse tests; multi-device soak before advertising.

## 4. Production server (owner's VPS)

- URL: **https://app.titangold.ir** (Caddy TLS) — PocketBase only listens on
  loopback; access the server via SSH alias **`zar-vps`** (`ssh zar-vps`,
  user `zaradmin`, key `~/.ssh/zar_vps`, `sudo -n` for root).
- Services (systemd): `zar-server` (PocketBase 0.40.4), `caddy`,
  `zar-backup.timer` (03:00 UTC atomic backups → `/backups/zar-daily`, with
  `SHA256SUMS` + `METADATA`), `zar-health-check.timer` (10 min checks, emails
  the owner via local Postfix).
- Off-site copy: the owner's PC pulls snapshots nightly
  (`server/tools/pull-offsite-backups.ps1`, deployed copy in
  `C:\Users\simin\ZAR-Ops\`).
- Deploy discipline for server changes: fresh backup → off-site pull →
  guarded deploy script or stop → `migrate up` → schema verify → start →
  postflight (health, NRestarts=0, listener, minute 0/5/15). Evidence doc per
  change in `docs/stabilization/`.
- Test data currently on production: 11 UX-campaign users
  `<ascii-name>@zarplus.cloud` (passwords in the local seeder script only) +
  the original `test@zarplus.cloud`. A stray Persian-email user
  (`سپهر@zarplus.cloud`) is pending cleanup.

## 5. Current project state (as of 2026-11-22)

- **v1.0.0** tagged + published as a GitHub release (post RC1 soak). Client
  versionCode **18082** (build-number 16082). Soak log: `SOAK-RC1.md`.
- Phase 0/1/2 of `docs/stabilization/ROADMAP-2026-11.md` are complete
  (integrity locks, rate limiting 13 rules, monitoring, off-site backup,
  transactional restore, Keystore token storage, supply-chain CI).
- Remaining known work: multi-device soak before advertising cloud
 reliability; signup reopen only at launch with abuse/rate-limit evidence.
 §10.5 cloud write CAS stack deployed (2026-11-23). §10.4 public signup
 closed and versioned (`1793604702`, prod 2026-11-23). Concurrent
 two-device CAS soak suite: `pocketbase_multi_device_cas_soak_test.py`.
- Android phone for device QA: Samsung, build-number ≥ 16082
  (installed versionCode = build-number + 2000), release-signed with the
  owner's keystore (cert pinned in `RELEASE-SIGNING-EVIDENCE`). adb notes:
  `input text` cannot type Persian; screencap+Read for verification;
  versionCode offset trap; dl.google.com is blocked on this network so
  `android/settings.gradle.kts` uses the Aliyun Google-Maven mirror.

## 6. Where to start

1. Read `docs/stabilization/PROGRAMMER-HANDOFF.md` (architecture + full
   history, Persian) and `docs/stabilization/ROADMAP-2026-11.md` (what's
   next).
2. Reproduce local CI: `flutter analyze --no-fatal-infos && flutter test`.
3. For UI work: `DESIGN.md` is mandatory. For server work:
   `TRANSACTIONAL-RESTORE-PLAN.md` + §0 of `HANDOFF.md` (post-handoff log).
4. Ship via branch → PR → CI → merge. Runbooks: `RELEASE-RUNBOOK.md`,
   `INCIDENT-RUNBOOK.md`, `RESTORE-RUNBOOK.md`.
