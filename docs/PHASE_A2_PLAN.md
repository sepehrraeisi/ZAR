# ZAR+ Phase A.2 — UX hardening before Firebase

This phase intentionally stays on mock/local data. Firebase remains out of scope until the UX is stable.

## Goals

1. Notification Center is a real destination, not a decorative bell.
2. Notification preferences cover privacy, default reminder offsets, sound/vibration/platform permission state, and snooze presets.
3. Archived people remain discoverable, searchable, openable, and restorable.
4. Archiving never deletes or detaches deals, settlements, or history.
5. Archiving a person with open obligations requires an explicit warning.
6. RTL remains global; LTR is isolated only to brand/currency/phone tokens.
7. Existing Home actions, Jalali pickers, currency selector, History, and five-tab navigation remain intact.

## Notification Center UX

Home bell opens `اعلان‌ها`.

Sections:
- `عقب‌افتاده`
- `امروز`
- `به‌زودی`

Notification rows derive from open settlement obligations in the current mock-data phase. They are tappable and open the related record. Unread state is subtle; the bell may show an unread badge.

Settings entry: `تنظیمات اعلان‌ها`.

Preferences (UI/state only in this phase):
- notifications enabled
- privacy: full / limited / private
- default reminder: 15m / 30m / 1h / 3h / 1d
- default snooze: 15m / 30m / 1h / 3h / tomorrow / custom
- sound: app default / silent (platform-specific custom sound work deferred until native notification service)
- vibration toggle where supported

Scheduling/persistence is deliberately separated from widgets so native local notifications and later FCM/APNs can be introduced without rewriting the screens.

## Archived People UX

People screen gets an `بایگانی‌شده‌ها` entry.

Archived list:
- searchable
- shows archived people
- person detail remains accessible
- provides `بازگردانی از بایگانی`

Archive rules:
- no hard delete
- all records remain attached by personId
- open obligations remain active
- if open obligations exist, confirm with the exact count before archive

## Implementation order

1. Add state/preferences models needed by Notification Center and archive UX.
2. Add Notification Center + settings screens.
3. Wire Home bell to Notification Center.
4. Add archived people list and restore callback.
5. Add archive confirmation for open obligations.
6. Add widget/model tests.
7. Run Flutter analyze/test/build in a Flutter-capable environment.
8. Only after review, prepare Firebase integration.
