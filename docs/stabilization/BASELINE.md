# ZAR+ Stabilization Baseline Evidence

Captured: 2026-10-28 (Asia/Tehran)  
Purpose: immutable identification data for the start of stabilization. This file contains no secrets and no customer data.

## Source repository

- Repository: `https://github.com/sepehrraeisi/ZAR`
- Default branch: `master`
- Baseline commit: `e60d68dda3c1876dc5af99e36c1f455b76fd8a50`
- Commit verification: unsigned
- GitHub API state at capture:
  - repository public
  - `master` reported unprotected
  - open pull requests: 0
  - open issues: 0
  - releases: 0
- Local stabilization branch: `codex/stabilization-baseline`

## Production service identity

- SSH target alias: `zar-vps`
- Hostname reported by server: `ubuntu`
- Server application root: `/opt/zar/server`
- Service: `zar-server.service`
- Service state at `2026-10-28T15:52:05Z`: `active/running`
- PocketBase version: `0.40.4`
- ExecStart: `/opt/zar/server/pocketbase serve --http=0.0.0.0:8090`
- systemd `User`/`Group`: unset, therefore root under the system service manager

## Production artifact checksums

SHA-256:

```text
14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a  /opt/zar/server/pocketbase
e3d38d487e8c64ded5691ab16b1b92dc6a1e15bed4eff994a69801ecbb4630aa  /opt/zar/server/pb_migrations/1758400000_zar_collections.js
ed63ff593fa7fc53fe32dd5f8850a6f70736dea8a62a8441b35f7345b162b97f  /opt/zar/server/pb_migrations/1790899200_cash_journal.js
132388ee2db3fda91b518192d398065dcd469bb88d509ab4a99800062050c613  /opt/zar/server/pb_migrations/1793020980_updated_users.js
ebe4707098be1a55d4eb68b5ce2837a1931d5197f3fff5fad755c9f13d907a2c  /opt/zar/server/pb_migrations/1793023512_updated_users.js
e74558d96fb64e1bed9f655aaf05d02f46b84ec4726429575244764f15a99334  /etc/systemd/system/zar-server.service
694597fc2cd0c259740ffb5df68d92e581dce5637790e2393bc9ad3c210dc4c4  /etc/caddy/Caddyfile
```

The first tracked migration is byte-identical to Git. The cash-journal migration has different byte hashes because the repository checkout uses CRLF, but its normalized LF text is exactly equal to production (`830` characters each). The two `179302*` migrations exist only on production at baseline; they customize Persian user email templates and must be recovered into version control after review.

## Production paths, modes and ownership

```text
/opt/zar/server/pocketbase              size=32727200  mode=755  owner=root:root
/opt/zar/server/pb_data/data.db         size=270336    mode=644  owner=root:root
/opt/zar/server/pb_data/auxiliary.db    size=1011712   mode=644  owner=root:root
/opt/zar/server/pb_migrations           size=4096      mode=755  owner=root:root
/etc/systemd/system/zar-server.service  size=236       mode=644  owner=root:root
/etc/caddy/Caddyfile                    size=81        mode=644  owner=root:root
```

The database file permissions are a confirmed security finding. Do not change them until a dedicated service user, backup, restore evidence and rollback sequence are prepared together.

## Database and current backup evidence

- Live `data.db` SQLite `PRAGMA quick_check`: `ok` at capture.
- Backups are local on the same server and do not yet satisfy disaster recovery requirements.
- Backup files are mode `0644` and therefore also require containment.

```text
zar-2026-10-25.db  size=266240  quick_check=ok  sha256=1f491301e7ce5194593ea2ebb63e83cc613b2d171e6612410ace6eb492498c12
zar-2026-10-26.db  size=266240  quick_check=ok  sha256=1f491301e7ce5194593ea2ebb63e83cc613b2d171e6612410ace6eb492498c12
zar-2026-10-27.db  size=270336  quick_check=ok  sha256=e3ba0b5acce74f3333e1f70684a0bbf3180f8081337354f56c48eff852651160
zar-2026-10-28.db  size=270336  quick_check=ok  sha256=e3ba0b5acce74f3333e1f70684a0bbf3180f8081337354f56c48eff852651160
```

`quick_check=ok` is necessary but not a restore drill. Required next evidence is a restored isolated PocketBase instance, schema verification, authentication/API checks and business-data reconciliation.

## Repository/production drift recorded

1. Production has two untracked user-template migrations.
2. Repository documentation and production both configure PocketBase on `0.0.0.0:8090`; hardening should move it to loopback behind Caddy.
3. Repository deployment documentation creates a root-run systemd service; this must be replaced by a least-privilege versioned unit.
4. Repository backup documentation describes only a local copy of `data.db`; it omits configuration, migrations, keys/certificates where applicable, encryption, off-site retention and restore/reconciliation.
5. `zar_workspaces.deleteRule` is committed as an empty string and is present in production; a new forward migration is required rather than editing applied migration history.

## Baseline limitations

- No hash or signing-certificate fingerprint of the APK installed on the user's phone is captured yet.
- No signing keystore was accessed or verified.
- Live database content was not copied into Git and must never be committed.
- The full restore and application-level reconciliation drill is pending.
- Caddy/systemd contents are intentionally not reproduced here; only their paths and hashes are recorded until sanitized templates are prepared.

