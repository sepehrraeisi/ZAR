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

## Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # or -d <android device>
```

CI runs `flutter analyze` and `flutter test` on every push to `master` and on
every pull request (`.github/workflows/phase_a2_ci.yml`).

## Reminder data ownership

Reminder intent is business data, not only device notification state.

Each `ZarSettlement` now owns a persistence-safe `ZarReminderPlan` containing:

- offset reminders such as 15m / 30m / 1h / 3h / 1d before
- custom reminder timestamps
- snoozed-until timestamp
- enabled state per rule

The plan is serialized with the settlement in Firestore and in the lossless domain backup. Native iOS/Android scheduling remains a separate delivery layer. This means restarting or replacing the phone does not erase the user's chosen reminder configuration once cloud persistence is active.

Legacy Firestore/backup settlement documents that do not yet contain `reminderPlan` remain readable and default safely to an empty plan.

## Reminder wiring (completed)

The live V2 shell (`repository_phase_a2_app_v2.dart`) wires reminder intent end to end:

- after repository load, every open settlement is scheduled from its persisted `ZarReminderPlan`
- a newly created settlement uses the device/user default reminder only when no explicit plan is selected
- Quick Add saves the selected reminder plan before native notifications are scheduled
- Snooze persists the new `snoozedUntil` before changing the native schedule
- reminder edits persist before the native schedule is replaced
- Complete/Cancel retain the historical reminder plan for audit/backup while cancelling obsolete native pending notifications
- after a successful Retry, the native schedule is reconciled from persisted settlement state

## Notification Center

- Home bell icon opens Persian RTL `اعلان‌ها`.
- Shows due soon, overdue, snoozed returns and upcoming deliveries/receipts.
- Notification items deep-link to the relevant record/settlement.
- Includes subtle unread state + optional unread badge/count.

### Notification settings (`تنظیمات اعلان‌ها`)

- اعلان‌ها: on/off
- صدا: supported app notification behavior/sound options within platform limits
- ویبره: where OS supports it
- حریم خصوصی اعلان: `کامل` / `محدود` / `خصوصی`
- یادآوری‌های پیش‌فرض: 15m, 30m, 1h, 3h, 1d before
- Snooze defaults: 15m, 30m, 1h, 3h, tomorrow, custom time

## Archived People

- Archive means hidden from active People list, not deleted/inaccessible.
- `اشخاص بایگانی‌شده` remains searchable, openable and restorable.
- Archiving does not delete/detach deals, settlements, history or audit logs.
- If a person has open obligations, archiving requires confirmation; it never cancels them.

## Safety constraints

- Firebase production integration remains paused until the correct configuration for `com.zarplus.app` is provided.
- Do not commit Firebase Admin keys, `.env`, signing keys, tokens or credentials.

## Windows development modes

Firebase remains in the application dependencies and its Dart bootstrap remains
opt-in. Local Windows UI development also keeps the native FlutterFire plugins
disabled by default, so the local persistent V2 experience does not download or
initialize the Firebase C++ SDK.

### Local Windows UI mode (default)

No Firebase flag is required:

```powershell
flutter pub get
flutter run -d windows
```

This mode uses `ZarLocalRepository` backed by Drift/SQLite. It retains the
Windows plugins needed for notifications, file selection, sharing and URL
launching, but it neither links nor initializes Firebase.

### Future Firebase-enabled Windows mode (explicit opt-in)

Only use this after the production Firebase project and native SDK path are
ready:

```powershell
$env:ZAR_ENABLE_FIREBASE_NATIVE = "ON"
flutter build windows --dart-define=ZAR_USE_FIREBASE=true
```

`ZAR_ENABLE_FIREBASE_NATIVE` selects Flutter's generated native plugin list and
registrant. The existing `ZAR_USE_FIREBASE` Dart define separately permits the
Firebase bootstrap. Both are opt-in; setting neither keeps local mode active.

To return the current PowerShell session to local mode:

```powershell
Remove-Item Env:ZAR_ENABLE_FIREBASE_NATIVE -ErrorAction SilentlyContinue
```

Do not edit `windows/flutter/generated_plugins.cmake` or the generated plugin
registrant files. Flutter owns and may regenerate them during `flutter pub get`.
When adding a non-Firebase Windows plugin, also add it to the manually owned
`windows/flutter/local_plugins.cmake` and, for method-channel plugins, to
`windows/runner/local_plugin_registrant.cc`.

## Local data persistence

Production startup opens a versioned Drift/SQLite database in the platform's
application documents directory. People, deals, settlements, archive state and
settlement reminder plans are stored as typed domain fields. Currency is stored
as integer minor units and scale; gold is stored as its normalized decimal text.
No `AppRecord` or calculated presentation value is stored.

JSON V7 is the portable backup format, including exact Toman deal pricing,
gold-market gram/mithqal inputs, coin bundles, the editable coin/currency type
catalog, and explicit payment allocations. Existing V2, V3, V4, V5 and V6
backups remain importable. Restore validates the complete
typed snapshot before opening one replacement transaction; a validation or
database failure rolls the transaction back. Native reminders are reconciled
only after persistence succeeds. Schema upgrades must be implemented as
explicit migrations—the app never deletes or recreates a user database as an
automatic recovery step.

### Customer operational position and explicit allocation

Priced purchases create Toman payable; priced sales create Toman receivable.
Unpriced legacy deals never invent a value. Free completed receive/payment
movements do not reduce either amount. Users explicitly choose destinations in
the allocation sheet after saving a Toman movement, or from its detail sheet.
Only completed, non-cancelled allocated movements reduce the chosen obligation.
Open allocated movements reserve their amount but do not discharge the target.

Drift schema 8 adds the editable coin/currency type catalog; schema 7 added
`zar_payment_allocations`: source settlement ID,
typed target kind/ID, and whole-Toman allocation amount. The composite primary
key prevents duplicate source/target allocations. Validation rejects mismatched
person/business/direction, missing targets, over-allocation and allocation chains.
No balances, inventory totals or accounting entries are persisted. `deliver`
remains the stored enum; its UI label is «پرداخت».

When a partially fulfilled original settlement is completed, inventory includes
only its remaining amount in addition to the separate completed movements.
Deals still move their own assets; linked settlements representing those same
asset identities/direction do not count again. A Toman payment for a foreign
currency/gold/coin deal remains an independent Toman inventory movement.

### Android reminder limitations

Normal and alarm-style reminders use versioned Android channels separated by
sound and vibration preferences. Old channels are retained; existing Android
user choices are not modified. The new channels use a stable record tag so an
already displayed alarm-style notification can be cancelled when the record is
acted upon. Old displayed notifications without this tag may need dismissal.

Scheduling remains `inexactAllowWhileIdle`. No exact-alarm or full-screen
permission is requested. Persistent/high-priority notification is not continuous
Clock-style ringing. Android notification permission, channel settings, Doze,
Samsung battery policy and force-stop can prevent or delay delivery. Changing
in-app preferences cannot override a system-muted channel. Verify foreground,
background, locked-screen, tap, snooze and cancellation behavior on the device.
