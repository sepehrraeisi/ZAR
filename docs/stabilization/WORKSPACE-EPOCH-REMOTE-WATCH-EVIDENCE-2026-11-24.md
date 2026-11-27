# Workspace epoch remote watch — Evidence (ZAR-DATA-002)

تاریخ: 2026-11-24 — شاخه: `feature/workspace-epoch-remote-watch`
مرجع: FINDINGS ZAR-DATA-002 (realtime / multi-device remainder)

## Scope

- Cloud repository tracks snapshot `epoch` and probes
  `GET /api/collections/zar_workspaces/records/{id}` for the current epoch.
- Shell polls every 15s + on app resume; when remote epoch advances past the
  last snapshot, it reloads the snapshot and shows a Persian snackbar.
- Local/preview repositories do not implement `ZarWorkspaceEpochSource`
  (watcher no-ops).
- Outside slice: PocketBase SSE `/api/realtime`, physical multi-device soak,
  next signed APK.

## Client

- `lib/data/zar_domain_repository.dart` → `ZarWorkspaceEpochSource`
- `lib/data/pocketbase/zar_pocketbase_repository.dart`
- `lib/application/zar_workspace_epoch_watcher.dart`
- `lib/repository_phase_a2_app_v2.dart`
- `test/zar_workspace_epoch_watcher_test.dart`
- `test/zar_pocketbase_repository_test.dart`

## Acceptance

- Watcher unit tests: unknown epoch / unchanged / advanced / pause+dispose
- PocketBase repository: captures snapshot epoch; peek hits workspace record
- `flutter analyze --no-fatal-infos` + targeted tests green

## Production

- Client-only; no server hook/migration deploy required (uses existing
  workspace viewRule + epoch field from ZAR-DATA-006).
- Ships with the next signed APK.

## Follow-up 2026-11-27

- Failed remote refresh after epoch advance shows the same Persian snackbar as
  conflict reload failure («تازه‌سازی ناموفق بود…») instead of failing silent.
