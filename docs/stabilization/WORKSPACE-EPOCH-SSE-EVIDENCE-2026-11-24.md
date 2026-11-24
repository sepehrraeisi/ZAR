# Workspace epoch SSE realtime — Evidence (ZAR-DATA-002)

تاریخ: 2026-11-24 — شاخه: `feature/workspace-epoch-sse-realtime`
مرجع: FINDINGS ZAR-DATA-002 (SSE realtime remainder after epoch poll)

## Scope

- Minimal PocketBase SSE client: GET `/api/realtime` → `PB_CONNECT` →
  POST subscriptions for `zar_workspaces/{id}` with auth.
- Workspace update events trigger the existing epoch check/reload path.
- 15s poll + resume check remain as resilience (proxy buffering / disconnect).
- Outside slice: Caddy flush tuning if SSE is buffered in production,
  physical multi-device soak, next signed APK.

## Client

- `lib/data/pocketbase/zar_pocketbase_sse.dart`
- `lib/data/pocketbase/zar_pocketbase_client.dart` (`httpClient` getter)
- `lib/data/pocketbase/zar_pocketbase_repository.dart`
- `lib/data/zar_domain_repository.dart` (`open/closeRemoteChangeSignals`)
- `lib/application/zar_workspace_epoch_watcher.dart`
- `lib/repository_phase_a2_app_v2.dart`
- tests: `zar_pocketbase_sse_parser_test.dart`, watcher push-signal case

## Acceptance

- SSE parser unit tests green
- Watcher push-signal + poll/pause tests green
- `flutter analyze --no-fatal-infos` on touched files

## Production

- Client-only; uses existing workspace ViewRule for single-record subscribe.
- No server hook/migration. Ships with the next signed APK.
- If Caddy buffers SSE, poll still covers multi-device within 15s.
