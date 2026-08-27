# ZAR+

Private Persian-first Flutter application for operational gold and currency work.

## Current Phase A.2 architecture

- Persian RTL + Jalali operational UI
- strict Deal vs Settlement separation
- repository-backed application state
- exact gold decimal strings and currency integer minor units
- Notification Center + archived people flows
- native local notification foundation for iOS/Android
- notification privacy, sound, vibration and device-local preferences
- notification deep-link record IDs and cold-start buffering
- confirmed-write / Retry foundation
- lossless production-domain JSON backup + Persian CSV export foundation
- Firestore mapper/repository, rules and indexes prepared but production Firebase remains disabled

## Reminder data ownership

Reminder intent is business data, not only device notification state.

Each `ZarSettlement` now owns a persistence-safe `ZarReminderPlan` containing:

- offset reminders such as 15m / 30m / 1h / 3h / 1d before
- custom reminder timestamps
- snoozed-until timestamp
- enabled state per rule

The plan is serialized with the settlement in Firestore and in the lossless domain backup. Native iOS/Android scheduling remains a separate delivery layer. This means restarting or replacing the phone does not erase the user's chosen reminder configuration once cloud persistence is active.

Legacy Firestore/backup settlement documents that do not yet contain `reminderPlan` remain readable and default safely to an empty plan.

## Next Development Pass (Do Not Skip)

### 1) Finish live reminder-plan wiring

The persistence model/store is now ready. The live shell still needs to stop treating the default reminder as the authoritative plan.

Required next wiring:

- after repository/workspace load, schedule each open settlement using its persisted `ZarReminderPlan`
- use the device/user default reminder only when a newly created settlement has no explicit plan
- Quick Add must save the selected reminder plan in the settlement before scheduling native notifications
- Snooze must persist the new `snoozedUntil` before changing the native schedule
- reminder edits must persist before native schedule replacement
- Complete/Cancel must retain historical reminder intent if desired for audit/backup, while cancelling obsolete native pending notifications
- after successful Retry, reconcile the native reminder schedule from the persisted settlement state

### 2) Notification Center remains a core operational feature

- Home bell icon opens Persian RTL `اعلان‌ها`.
- Show due soon, overdue, snoozed returns and upcoming deliveries/receipts.
- Notification items deep-link to the relevant record/settlement.
- Include subtle unread state + optional unread badge/count.

#### Notification settings (`تنظیمات اعلان‌ها`)

- اعلان‌ها: on/off
- صدا: supported app notification behavior/sound options within platform limits
- ویبره: where OS supports it
- حریم خصوصی اعلان: `کامل` / `محدود` / `خصوصی`
- یادآوری‌های پیش‌فرض: 15m, 30m, 1h, 3h, 1d before
- Snooze defaults: 15m, 30m, 1h, 3h, tomorrow, custom time

### 3) Archived People must never disappear

- Archive means hidden from active People list, not deleted/inaccessible.
- `اشخاص بایگانی‌شده` remains searchable, openable and restorable.
- Archiving must not delete/detach deals, settlements, history or audit logs.
- If a person has open obligations, require confirmation; do not cancel them.

## Safety constraints

- Firebase production integration remains paused until the correct configuration for `com.zarplus.app` is provided.
- Do not commit Firebase Admin keys, `.env`, signing keys, tokens or credentials.
- Do not merge the Phase A.2 PR until CI/device validation is available.
