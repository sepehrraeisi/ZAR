# Catalog CAS conflict UX — Evidence

تاریخ: 2026-11-27
مرجع: conflict-reload pattern (ZAR-DATA-002); coin/currency already CAS via upsert

## Scope

- Coin/currency catalog saves/archives/restores go through the write
  coordinator and rethrow `ZarCloudWriteConflictException`.
- Catalog screens show typed conflict copy + SnackBar **تازه‌سازی** when
  `needsReload` (same Persian copy as editors).
- Client-only; no server deploy.

## Client

- `repository_phase_a2_app_v2.dart` `_catalogWrite` + `onReload`
- `coin_catalog_screen.dart` / `currency_catalog_screen.dart`
- Tests: `test/master_data_catalog_screen_test.dart`,
  `test/zar_pocketbase_repository_edge_test.dart` (catalog 409 → staleRevision)

## Production

- Ships with the next signed APK after 20086.
