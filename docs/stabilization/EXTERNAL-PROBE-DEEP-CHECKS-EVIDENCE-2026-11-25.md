# External probe deep checks — TLS + off-site backup age

تاریخ: 2026-11-25  
اسکریپت: `server/tools/zar_external_probe.ps1`  
مرجع باز: ROADMAP فاز ۲ «TLS/backup-age deep probes still optional hardening»

## Change

Outside-in probe (owner PC, Task Scheduler every 15 min) now checks, in order:

1. `GET https://app.titangold.ir/api/health` → HTTP 200 + body contains `healthy`
2. TLS leaf for `app.titangold.ir` as seen by this client → **> 14 days** remaining
3. Newest local directory under `%USERPROFILE%\Documents\ZAR-OffsiteBackups`
   matching `zar-YYYYMMDDTHHMMSSZ` → age **< 50 hours** (daily pull; PC may miss
   one night — looser than on-VPS 26h backup check)

On any failure: append `FAIL` to `%USERPROFILE%\ZAR-Ops\external-probe.log` and
show a Windows MessageBox (same alert path as before). Success logs
`OK health=200 tlsDays=… offsite=… ageHours=…`.

## Verification (this PC)

Pre-pull (stale local set still under 50h):

```text
OK health=200 tlsDays=59 offsite=zar-20261124T162618Z ageHours=21.8
```

After `pull-offsite-backups.ps1` (read-only SSH pull; latest
`zar-20261125T030150Z`, SHA + quick_check OK):

```text
OK health=200 tlsDays=59 offsite=zar-20261125T030150Z ageHours=11.3
```

- Health and TLS are independent of VPS `openssl` loopback check.
- Off-site age uses the snapshot **name** timestamp (UTC), not directory mtime.
- Scheduled copy at `C:\Users\simin\ZAR-Ops\zar_external_probe.ps1` updated to
  match repo (SHA-256 identical). No production server mutation.

## Non-goals

- Does not replace on-VPS `zar-health-check` email alerts.
- Does not open signup, mutate PocketBase, or touch BIND/Postfix.
