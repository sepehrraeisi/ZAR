# Multi-device physical soak checklist (ZAR-DATA-002)

Gate before advertising cloud multi-device reliability.
Engineering CAS soak (CI) is already green; this checklist is the
**physical** gate on real Android devices against `https://app.titangold.ir`.

## Preconditions

- Two devices (or one phone + one emulator) signed in to the **same**
  workspace with distinct sessions.
- Release APK ≥ versionCode **20083** (epoch poll + SSE + actor stamp +
  conflict reload). Cert SHA-256 must be `d19ad112…2667`.
- Signup remains closed; use seeded UX-campaign / owner accounts only.
- Caddy `flush_interval -1` deployed (public `/api/realtime` streams
  `PB_CONNECT`).

## Script (per pair, ≥ 30 minutes continuous)

1. **Baseline** — both devices open the people list; note open settlement
   count for one customer.
2. **Create on A** — add a person (or note) on device A; within ~15s (or
   sooner via SSE) device B shows the change without manual pull. Snackbar
   «تغییر از دستگاه دیگر» is acceptable.
3. **Conflict** — open the same settlement note on A and B; save A first,
   then save B with a different note → B gets conflict + **تازه‌سازی**;
   after reload, B’s save succeeds or shows the A value.
4. **Terminal freeze** — complete a settlement on A; B attempts to change
   amount/direction → `terminal_field_locked` / lifecycle message; note-only
   edit still works.
5. **Cash** — append a cash entry on A (if cloud cash path enabled for the
   build); B sees it after reload/epoch. If cash remains device-local, skip
   and note that in the log.
6. **Airplane** — toggle airplane on B for 60s during A writes; on restore,
   B catches up via poll/SSE without duplicate rows.
7. **Resume** — background B, write on A, foreground B → reload without
   crash.

## Pass criteria

- No silent last-write-wins; conflicts are visible.
- No duplicate people/settlements from retries.
- No P0/P1 attributable to ZAR+ during the window.
- Record: devices, APK SHA-256, versionCode, start/end UTC, anomalies.

## Log template

```text
Date (UTC):
Devices:
APK versionCode / SHA-256:
Commit:
Observer:
Pass/Fail:
Notes:
```
