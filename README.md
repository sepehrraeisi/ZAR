# ZAR+

ZAR+ is a Persian-first, RTL-first Flutter application for operational gold and foreign-currency workflows.

## Product direction

- iPhone-first Flutter UX
- Persian UI with Jalali calendar
- strict separation between **Deal** (خرید / فروش) and **Settlement** (دریافت / تحویل)
- Firebase/Firestore planned as the authoritative cloud source of truth
- device-local notification preferences only for non-authoritative UX settings
- structured reminders, auditability, archive/restore, backup/export

## Current development branch

Primary active branch:

`codex/phase-a2-ux`

The `master` branch remains the preserved Genspark checkpoint until Phase A.2 is validated.

## Phase A.2 implemented foundation

Current branch includes:

- repository-backed operational app shell
- Persian RTL/Jalali Home, Calendar, People and History flows
- Quick Add with gold/currency separation and currency selector
- People archive + archived-people search + restore
- Notification Center and notification preferences
- local iOS/Android reminder scheduling foundation
- notification privacy modes: کامل / محدود / خصوصی
- device-local persistence for notification preferences
- native notification tap buffering for cold-start/bootstrap timing
- notification tap routing into the exact Deal/Settlement once the repository workspace is ready
- confirmed-write coordination for business mutations
- Complete / Cancel / Reschedule / Archive only dismiss after confirmed persistence
- failed writes remain visible and expose Persian Retry feedback
- bounded iOS pending-notification policy that keeps the nearest reminders and preserves authoritative reminder plans for later queue refresh
- decimal-safe gold quantities and integer minor-unit currency values
- typed production-domain models and repository boundary
- Firestore repository/schema/security-rule foundation (production connection still disabled)
- versioned JSON backup foundation + Persian CSV export
- Persian email/password auth UI foundation

## Safety / data-integrity rules

ZAR+ must never claim that a business record was saved unless the persistence operation completed successfully.

Core business records must not live only in local preferences or device cache.

Archived people must remain recoverable and their historical Deals/Settlements must remain intact.

Completed/cancelled obligations must cancel obsolete reminder schedules.

## Firebase status

Production Firebase remains intentionally disabled until configuration matches the final package identity:

`com.zarplus.app`

Do not reuse a `google-services.json` or Apple Firebase configuration generated for another package/bundle identifier.

## Validation status

GitHub Actions passed Flutter analyze/tests/web build earlier in Phase A.2. Recent GitHub-hosted runner jobs are currently failing before any workflow step starts (`steps: null` / no usable job execution), so new native changes still require a healthy CI runner and real-device validation before merge.

Native notifications especially require real iPhone/Android validation for:

- permission flow
- Focus / Silent mode behavior
- lock-screen privacy
- sound/vibration behavior
- notification tap deep-link behavior
- reboot/update rescheduling behavior

## Next Development Pass (Do Not Skip)

### 1. Notification Center

The Home bell is a real operational entry point, not decoration.

Notification Center requirements:

- overdue reminders
- due-soon reminders
- upcoming receive/deliver obligations
- snoozed reminders returning
- unread state / restrained badge
- tap notification → open related record
- settings access

Notification settings include:

- enable/disable
- sound
- vibration where supported
- system notification settings shortcut
- privacy: کامل / محدود / خصوصی
- default reminder preset
- default snooze preset

### 2. Archived People

Archive means hidden from the active People list, not deleted.

Archived People must support:

- search
- open person detail
- restore
- historical Deal/Settlement continuity
- warning when archiving a person with open obligations

### 3. Remaining pre-Firebase hardening

Before enabling production Firebase:

- validate current branch on a healthy Flutter CI runner
- run real-device iOS/Android notification tests
- verify iOS bounded pending-notification refresh with many future obligations
- further reduce legacy `AppRecord` / presentation ownership where practical
- finish end-to-end user-facing JSON export/import flow
- perform final Persian RTL/Jalali visual QA

## Merge policy

Do not merge Phase A.2 into `master` while CI runner validation is unavailable or native notification behavior has not been exercised on real devices.
