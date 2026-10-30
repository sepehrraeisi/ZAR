# ZAR+ Production Containment Evidence — 2026-10-30

Change identifier: `zar-containment-20261030T114150Z`
Execution window: 2026-10-30 11:46:50–11:47:17 UTC
Result: **PASS — containment applied; rollback not required**

## Scope

Applied only these forward migrations to PocketBase `0.40.4`:

- `1793260800_lock_workspace_deletion.js`
- `1793347200_lock_cash_entry_deletion.js`

No application binary, Caddy, SSH, systemd, firewall, Android client or business row was intentionally changed.

## Authorization and temporary recovery exception

The owner confirmed there are no customers and accepted the documented temporary lack of an independent cloud/second-media backup. This exception expires before customer data/public launch or 2026-11-30.

Before the change, a full recovery set was copied off the production server to the owner's Windows computer, encrypted, decrypted and manifest-verified.

Pre-change encrypted bundle:

```text
file:   zar-pre-containment-20261030T114150Z.tar.gpg
sha256: 3b3d24d964217a1ba7580f5086101e7fc73f625a44a14710e611029bb95059e6
files:  10 verified
```

The exact database copy passed the isolated PocketBase health, SQLite integrity, migration and eight-table reconciliation gate.

## Pre-change production evidence

- Service: active; `NRestarts=0`
- PocketBase: `0.40.4`
- Internal and public health: HTTP `200`
- PocketBase binary SHA-256: `14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a`
- Fresh online backup:
  - `/backups/zar-pre-containment-20261030T114150Z.db`
  - SHA-256 `a0da2edc42d46ddff0737ccaa4e40be7f5b141b3be92188c7cbae00828948907`
  - `quick_check=ok`, `integrity_check=ok`
- Stopped-state rollback backup:
  - `/backups/zar-stopped-pre-containment-20261030T114150Z.db`
  - SHA-256 `a0da2edc42d46ddff0737ccaa4e40be7f5b141b3be92188c7cbae00828948907`
- Stopped-state migration archive:
  - `/backups/zar-stopped-pre-containment-20261030T114150Z-pb_migrations.tar`
  - SHA-256 `7841bc0ffd6653904f67047c390ba77ffae470a4d9b68e358f2deaa823860c0b`

Pre-change rules confirmed the defects:

- `zar_workspaces.deleteRule` was an empty/public rule.
- `zar_cash_entries.updateRule` was `NULL`, but `deleteRule` allowed workspace members.

Pre-change record counts:

```text
zar_workspaces     1
zar_people         1
zar_deals          0
zar_settlements    1
zar_coin_types     0
zar_currency_types 0
zar_allocations    0
zar_cash_entries   0
```

## Artifact verification

The staged and installed migration hashes matched the reviewed branch:

```text
694809da2509545844096a3c59b54fffdb80ec56759de3fd54cbcc8be6064ce3  1793260800_lock_workspace_deletion.js
d18818f2b0776007e6e6b83103740956db36e2b1f8636cb7a002ca62375ba09d  1793347200_lock_cash_entry_deletion.js
```

PocketBase reported:

```text
Applied 1793260800_lock_workspace_deletion.js
Applied 1793347200_lock_cash_entry_deletion.js
```

## Post-migration stopped-state validation

- `quick_check=ok`
- `integrity_check=ok`
- Both migration filenames appeared exactly once in `_migrations`.
- `zar_workspaces.deleteRule=NULL`
- `zar_cash_entries.updateRule=NULL`
- `zar_cash_entries.deleteRule=NULL`
- All eight record counts matched the pre-change values.

## Service validation

- Stop time: 2026-10-30 11:46:50 UTC
- Start time: 2026-10-30 11:47:17 UTC
- Measured maintenance interval: approximately 27 seconds
- New process started normally; `NRestarts=0`
- Internal health: HTTP `200`
- `https://app.titangold.ir/api/health`: HTTP `200`
- `https://zar.185-126-202-104.sslip.io/api/health`: HTTP `200`
- External direct access to port `8090`: timed out as expected
- Warning/error journal entries after start: none

No destructive API test was run against a production business record. The exact rules and migrations had already passed disposable real-PocketBase authorization tests where workspace/cash deletion returned `403`, record survival was confirmed and reversal creation returned `200`.

## Post-change recovery evidence

Post-change SQLite backup:

```text
path:   /backups/zar-post-containment-20261030T114728Z.db
sha256: 1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8
checks: quick_check=ok; integrity_check=ok
```

The post-change full recovery set was copied to the owner's Windows computer, restored in disposable PocketBase with no pending migrations, then encrypted and decrypted for verification:

```text
file:   zar-post-containment-20261030T114728Z.tar.gpg
sha256: 90aefdfed3ebdbc3fff84cf2be3b81d2516c2b0f54d381f4ba8c5e5334a289ec
files:  12 verified
restore health: pass
domain reconciliation: pass
```

Local protected location:

```text
C:\Users\simin\Documents\Codex\ZAR-Recovery
```

## Final decision

Go. The two containment migrations remain active. Rollback was not invoked.

Remaining urgent risks are not part of this change: public signup policy, root-run service, `0.0.0.0` binding, SSH root/password access, secure Android token/data storage, server-side accounting invariants, audit trail and multi-device conflict control.
