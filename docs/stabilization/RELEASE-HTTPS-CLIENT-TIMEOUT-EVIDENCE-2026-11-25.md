# Release HTTPS enforce + REST client timeout (P2 hardening)

تاریخ: 2026-11-25 — شاخه: `feature/release-https-and-client-timeout`

## Goal

Close the handoff P2 item «enforce HTTPS در release و timeout/cancellation
صریح» for the PocketBase path without breaking disposable HTTP test servers.

## Client

- `validateZarPocketBaseBaseUrl` — absolute URL + host; when `requireHttps`
  (default `kReleaseMode`) rejects non-`https`.
- `ZarPocketBaseClient`: constructor runs the validator; each REST `_send`
  applies `timeout` (default 30s) to `send` and body read; `TimeoutException`
  → `ZarPocketBaseTransportException`. SSE keeps using `httpClient` directly
  (long-lived stream).

## Android

- Main: `usesCleartextTraffic=false` + `network_security_config` base-config
  cleartext denied.
- Debug overlay: `usesCleartextTraffic=true` for local disposable PB.

## Tests / CI

- `test/zar_pocketbase_client_test.dart` (8 cases) — HTTPS gate + timeout map.
- `phase_a2_ci.yml` flutter-checks asserts cleartext=false + network security
  XML markers (alongside backup-deny asserts).

## Local run

```text
flutter test test/zar_pocketbase_client_test.dart
→ All tests passed! (+8)
```

## Ship note

Takes effect on the **next** signed release APK. Production server already
serves HTTPS via Caddy; no VPS change.
