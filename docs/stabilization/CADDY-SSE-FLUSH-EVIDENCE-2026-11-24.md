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

## Production deploy (2026-11-24)

- PR #58 merged (`a3ed85c`); required CI checks green.
- Fresh atomic backup `zar-20261124T152929Z` + off-site under
  `Documents\ZAR-OffsiteBackups\zar-20261124T152929Z`.
- Rollback copy: `/var/tmp/zar-caddy-sse-flush-rollback-20261124T1525Z/Caddyfile`.
- Installed versioned `server/deploy/Caddyfile` → `/etc/caddy/Caddyfile`;
  `caddy validate` ok; `systemctl reload caddy`.
- Postflight: `caddy` active; PocketBase health `200`; public `/_/` and
  `/api/settings` → **404**; `flush_interval -1` present.
- Public SSE smoke: `GET https://app.titangold.ir/api/realtime` streamed
  `event:PB_CONNECT` with a `clientId` (curl idle timeout expected).
