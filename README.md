# flutter_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Next Development Pass (Do Not Skip)

### 1) Notification Center is a core operational feature
- Home bell icon must open a real Persian RTL `اعلان‌ها` screen (not decorative).
- Must show operational reminder events: due soon, overdue, snoozed returns, upcoming deliveries/receipts.
- Notification items must be tappable and deep-link to the relevant record/settlement.
- Include subtle unread state + optional unread badge/count on bell.
- Keep the UI minimal and operational (not social feed style).

#### Notification settings (`تنظیمات اعلان‌ها`)
- اعلان‌ها: on/off
- صدا: supported app notification behavior/sound options within platform limits
- ویبره: where OS supports it
- نمایش روی صفحه قفل: based on permissions/platform capability
- حریم خصوصی اعلان: `کامل` / `محدود` / `خصوصی`
- یادآوری‌های پیش‌فرض: 15m, 30m, 1h, 3h, 1d before
- Snooze defaults: 15m, 30m, 1h, 3h, tomorrow, custom time

#### Notification architecture requirement
- Keep notification UI and scheduling as separate services.
- Support: local scheduling, update-on-reschedule, cancel-on-complete/cancel, deep-link open.
- Prepare architecture for future FCM/APNs and multi-device sync.

### 2) Archived People must never disappear
- Archive means hidden from active People list, not deleted/inaccessible.
- Add explicit destination/filter: `بایگانی‌شده‌ها` / `اشخاص بایگانی‌شده`.
- Archived people must remain searchable, openable, and restorable (`بازگردانی از بایگانی`).
- Archiving must not delete/detach deals, settlements, history, audit logs, or completed records.
- If person has open obligations, require confirmation before archive; do not silently cancel obligations.

### Constraints for next pass
- Firebase integration remains paused.
- Resume from Phase A.1 codebase after this GitHub backup.
