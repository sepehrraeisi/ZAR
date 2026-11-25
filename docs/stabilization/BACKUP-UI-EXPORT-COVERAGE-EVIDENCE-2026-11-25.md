# Backup UI export / account coverage (P2)

تاریخ: 2026-11-25 — شاخه: `feature/backup-screen-export-coverage`

## Suite

`test/backup_screen_export_coverage_test.dart` (alongside existing
`backup_screen_restore_guard_test.dart`):

- save export → `saveJson` + snackbar «نسخه پشتیبان ذخیره شد.»
- share export → `shareJson` + share snackbar
- import preview cancel → no restore success
- account card shows email/serverUrl + confirmed sign-out
- coin/currency catalog buttons invoke callbacks
- invalid picked JSON → format snackbar

## Local

```text
flutter test test/backup_screen_export_coverage_test.dart
→ All tests passed! (+6)
```

## Remaining P2 coverage

- repository edge cases beyond the large PocketBase repository suite
