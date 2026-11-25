# RC soak window — start log (post-v1.0.0 hardening)

تاریخ شروع (UTC): 2026-11-25  
هدف: ۷–۱۴ روز بدون P0/P1 قبل از تبلیغ cloud multi-device / لانچ عمومی

## Build under soak

- APK versionCode **20084** (SHA-256 `6464fa70…d909`, cert `d19ad112…2667`)
- Master tip at soak start: after PR #75 (`77d8520` era; confirm at close)
- Server: signup still **closed**; CAS + epoch/SSE + Caddy flush already in prod

## Daily watch (owner / ops)

- `zar-health-check` / external probe green
- No unexplained `zar-server` restart loops
- Off-site backup pull continues nightly

## Gates still outside this soak

- Physical **two-device** soak (separate checklist)
- Signup reopen (owner)
- Period lock (accountant)
- Local DB encryption (owner ADR)

## Close criteria

- ≥7 days, zero P0/P1 attributed to ZAR+
- HANDOFF §0 line with Pass + end UTC
- Optional: extend to 14 days before advertising
