# Settlement detail note refresh — 2026-11-25

## Symptom (physical soak, APK 20084)

On Samsung and moto e13 (same workspace `shahab@zarplus.cloud`):

1. Open an open settlement → ویرایش → change یادداشت (e.g. `تست توضیحات`) → save.
2. Write reaches the server (cross-device sync Pass; reopening the detail shows the new note).
3. The still-open `RepositorySettlementActionSheet` kept showing the pre-edit note until the user dismissed and reopened it.

## Root cause

`ConfirmedRecordEditorSheet` already pops the updated `AppRecord` on success. `_openRecord` ignored that return value and the action sheet stayed a `StatelessWidget` bound to the opening snapshot.

## Fix

In `_openRecord`, wrap the sheet in `StatefulBuilder`, keep a `current` record, and after the editor returns a non-null record call `adopt(edited)` (`_store.recordById` preferred) so یادداشت / date fields rebuild in place.

## Tests

`test/history_detail_test.dart` — `settlement detail refreshes note without dismiss/reopen`.

## Soak note

Logged under `.tmp-soak/SOAK-PHYSICAL-LOG.txt` (local soak artifacts; not committed).
