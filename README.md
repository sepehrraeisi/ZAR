# ZAR+

ZAR+ is a private Persian-first Flutter application for operational gold and foreign-currency workflows.

## Current development status

Development is continuing on `codex/phase-a2-ux` before production Firebase activation.

### Implemented foundation

- Persian-first RTL / Jalali operational UI
- strict Deal vs Settlement separation
- Home actions for complete / cancel / reschedule / snooze
- Notification Center and notification settings foundation
- archived people list with Restore
- exact gold decimal model and exact currency minor-unit model
- Persian/Arabic/Latin amount parsing without binary floating point
- structured reminder plans and reminder lifecycle registry
- repository boundary (`ZarDomainRepository`) independent from Firestore
- deterministic in-memory repository for tests and previews
- Firestore mapper/repository, audit-write foundation, security rules and indexes
- versioned JSON backup and Persian CSV export foundation
- Persian email/password authentication UI foundation

### Repository-backed UI migration

The default pre-Firebase launch path is now repository-backed.

- `ZarWorkspaceController` owns repository-backed operational state and mutations.
- `ZarLegacyPresentationBridge` converts between the current presentation types and production `Zar*` domain models while preserving exact currency/gold values.
- `ZarPhaseA2Store` loads active/archived people plus recent deals/settlements through `ZarDomainRepository` and exposes them to the current UI shape.
- `RepositoryZarPlusApp` is now launched from `main.dart` and uses `ZarPhaseA2Store` as its data source.
- preview seed data is represented as production domain objects inside `InMemoryZarDomainRepository`, not as widget-owned mutable records.
- create/edit/complete/cancel/reschedule/archive/restore operations pass through the repository boundary.
- repository write failures show a Persian error instead of silently reporting success.
- `ZarDomainRepository` includes recent history queries needed by the History tab and startup hydration.
- `ZarFirestoreRepository` implements the same history/query contract so switching from preview data to Firestore does not require widget-level database code.

The legacy presentation bridge remains transitional. Firestore must never depend on legacy presentation models or formatted display amounts.

## Firebase safety

Firebase dependencies are present, but production activation remains intentionally opt-in until the correct Firebase application configuration for package/bundle identity `com.zarplus.app` is available.

Do not commit service-account keys, `.env` secrets, signing keys, APNs credentials, or Firebase admin credentials.

## CI note

GitHub Actions previously completed Flutter analyze, tests and web preview builds successfully on this branch. Recent hosted-runner jobs are failing before the first workflow step starts (`steps: null`) and therefore currently provide no actionable Flutter compiler/test failure. Do not merge this branch until a normal runner execution validates the latest repository/store/parser/default-app tests.

## Next Development Pass (Do Not Skip)

### Notification Center

The Home bell is a real operational entry point, not decorative. The final native implementation must support scheduled reminder delivery, cancellation/rescheduling, privacy levels, sound/vibration within platform capability, notification deep-linking and later FCM/APNs multi-device support.

### Archived People

Archive means hidden from the active People list, never deleted. Archived people must remain searchable/openable, retain all deals/settlements/history, and support Restore. Open obligations are not silently cancelled by archiving.

### Remaining production work

1. Finish removing the remaining legacy presentation types from business-state ownership while preserving the approved minimal UI.
2. Harden async write UX so sheets close only after confirmed successful persistence and expose retry where appropriate.
3. Activate Firebase Auth/Firestore only with the correct `com.zarplus.app` configuration.
4. Implement real native scheduled notifications and real-device iOS validation.
5. Validate backup/restore and disaster-recovery flows before production use.
