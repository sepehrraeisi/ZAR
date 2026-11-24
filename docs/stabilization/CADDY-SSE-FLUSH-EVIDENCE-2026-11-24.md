# Caddy SSE flush for PocketBase realtime — Evidence (ZAR-DATA-002)

تاریخ: 2026-11-24 — شاخه: `feature/caddy-sse-flush-interval`
مرجع: FINDINGS ZAR-DATA-002 / `WORKSPACE-EPOCH-SSE-EVIDENCE-2026-11-24.md`

## Scope

- Versioned Caddy reverse_proxy sets `flush_interval -1` so
  `GET /api/realtime` is not buffered behind TLS.
- Keeps existing admin-route containment and `X-Zar-Client-IP` rewrite.
- Canary fixture mirrors the flush directive.
- Outside slice: physical multi-device soak, next signed APK.

## Files

- `server/deploy/Caddyfile`
- `server/tests/fixtures/Caddyfile.rate-limit-canary`

## Acceptance

- `caddy validate --config` green on the updated file
- Public `/api/realtime` streams a `PB_CONNECT` event without long delay
- Admin/management routes remain `404`; health `200`

## Production deploy

(filled after merge + reload)
