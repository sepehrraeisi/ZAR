# ZAR+ PocketBase Service Hardening Evidence — 2026-10-30

Change identifier: `zar-service-hardening-20261030T115652Z`
Maintenance interval: 2026-10-30 11:58:25–11:58:26 UTC
Result: **PASS — least-privilege service and loopback-only listener active; rollback not required**

## Pre-change state

```text
process: root:root
command: /opt/zar/server/pocketbase serve --http=0.0.0.0:8090
pb_data: 0755 root:root
data.db: 0644 root:root
listener: wildcard TCP 8090
systemd exposure: 9.6 UNSAFE
NRestarts: 0
```

Caddy was already configured to reverse-proxy both public hostnames to `127.0.0.1:8090`.

## Canary gate

Before changing the live unit, an isolated SQLite recovery copy was started on `127.0.0.1:18090` under the exact proposed account and systemd sandbox.

- Account: `zarapp` UID `996`, GID `987`, locked password, `/usr/sbin/nologin`.
- Process: `zarapp:zarapp`.
- Data directory/file: `0700`/`0600`, owned by `zarapp`.
- API health: HTTP 200.
- SQLite quick/integrity checks: `ok` / `ok`.
- Listener: `127.0.0.1:18090` only.
- Systemd exposure: `2.8 OK`.
- Error journal: no entries.

The canary was stopped after the test. Its exact `/var/lib/zar-hardening-canary` data copy and temporary scripts were deleted after production validation; the production database and rollback backups were not deleted.

## Rollback evidence

```text
server config archive:
  /root/zar-service-hardening-20261030T115652Z/service-config.tar
  sha256 36f2032896d64ad3b03d79dcd846077ce92d5ccb32fa508e48c744f1556a238f

stopped-state SQLite backup:
  /backups/zar-stopped-pre-service-hardening-20261030T115652Z.db
  sha256 1e69709378b3d9fe816d86639f5517e8b7af10676b00d597c4ee69e43d7e9ee8

stopped-state full pb_data archive:
  /backups/zar-stopped-pre-service-hardening-20261030T115652Z-pb_data.tar
  sha256 6d8f09ee00233d65be545ce51abbde0a64b2e8b7c32dd5d0ccab689d480eb67f

off-server evidence archive:
  work/service-recovery-20261030T115652Z/zar-service-hardening-20261030T115652Z-evidence.tar
  sha256 b0a4c8b450d5810c18c7609bbad570e2681cd2b6f4350a0e1e3bec37e55f468f
```

Both stopped-state artifacts are mode `0600` on the server. The SQLite hash is also identical to the already decrypted, manifest-verified encrypted post-containment recovery set on the owner's computer.

## Applied service policy

- `User=zarapp`, `Group=zarapp`, `UMask=0077`.
- PocketBase bind changed to `127.0.0.1:8090`.
- `/opt/zar/server` remains root-owned; binary remains `0755 root:root`.
- `pb_migrations` remains `0755 root:root` with read-only migration files.
- `pb_data` is `0700 zarapp:zarapp`; database files are `0600 zarapp:zarapp`.
- Only `pb_data` is writable inside the service filesystem sandbox.
- Linux capability and ambient capability sets are empty.
- `NoNewPrivileges=1` verified from the live process.
- Home, devices, temporary files, kernel/control-group surfaces, process view and namespaces are restricted.
- Address families limited to Unix, IPv4 and IPv6.
- Drop-in SHA-256: `f8401b1675de52909a40010e163f28b39965db9a49bdac72732089d19a36ad3d`.

## Production validation

- Measured maintenance interval: approximately one second.
- Active process: `zarapp:zarapp`, UID `996`, GID `987`.
- Active listener: `127.0.0.1:8090` only.
- Direct external TCP `8090`: closed/filtered.
- Internal API health: HTTP 200.
- `https://app.titangold.ir/api/health`: HTTP 200 from server and independent client.
- `https://zar.185-126-202-104.sslip.io/api/health`: HTTP 200 from server and independent client.
- SQLite quick/integrity checks: `ok` / `ok`.
- Domain/user record counts: byte-for-byte comparison passed; values unchanged.
- Migration history: byte-for-byte comparison passed; all 14 entries unchanged.
- `NRestarts=0`.
- Service error journal: no entries.
- Systemd exposure improved from `9.6 UNSAFE` to `2.8 OK`.
- SSH via `zaradmin` and non-interactive sudo remained functional.

## Remaining operations work

- Resolved on 2026-10-30: the legacy root cron was replaced by the verified
  systemd backup service/timer; its first natural run passed on 2026-10-31. See
  `BACKUP-AUTOMATION-EVIDENCE-2026-10-30.md`.
- Resolved on 2026-10-31: the public reverse proxy now denies the PocketBase
  admin/management surface and operators use a verified SSH local tunnel. See
  `ADMIN-ACCESS-CONTAINMENT-EVIDENCE-2026-10-31.md`.
- Add a separately reviewed SSH/HTTP rate-limit or ban policy.
- Decide the intended public signup policy before customer or launch data.
- Test service and backup restoration again after any future PocketBase upgrade.
