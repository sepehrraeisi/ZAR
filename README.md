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

The polished Phase A.2 UI still uses the original lightweight `AppPerson` / `AppRecord` presentation types, but it now has a production migration path:

- `ZarWorkspaceController` owns operational repository-backed state and mutations.
- `ZarLegacyPresentationBridge` converts between the current presentation types and production `Zar*` domain models while preserving exact currency/gold values.
- `ZarPhaseA2Store` loads people, recent deals and settlements through `ZarDomainRepository` and exposes them to the current UI shape.
- create/edit/complete/cancel/reschedule/archive/restore operations can now pass through the repository boundary rather than directly mutating Firestore or relying on display strings.

This bridge is transitional. Firestore must never depend on legacy presentation models.

## Firebase safety

Firebase dependencies are present, but production activation remains intentionally opt-in until the correct Firebase application configuration for package/bundle identity `com.zarplus.app` is available.

Do not commit service-account keys, `.env` secrets, signing keys, APNs credentials, or Firebase admin credentials.

## CI note

GitHub Actions previously completed Flutter analyze, tests and web preview builds successfully on this branch. Recent hosted-runner jobs are failing before the first workflow step starts (`steps: null`) and therefore currently provide no actionable Flutter compiler/test failure. Do not merge this branch until a normal runner execution validates the latest repository/store/parser tests.

## Next Development Pass (Do Not Skip)

### Notification Center

The Home bell is a real operational entry point, not decorative. The final native implementation must support scheduled reminder delivery, cancellation/rescheduling, privacy levels, sound/vibration within platform capability, notification deep-linking and later FCM/APNs multi-device support.

### Archived People

Archive means hidden from the active People list, never deleted. Archived people must remain searchable/openable, retain all deals/settlements/history, and support Restore. Open obligations are not silently cancelled by archiving.

### Remaining production work

1. Switch the default Phase A.2 shell from direct local lists to `ZarPhaseA2Store`.
2. Preserve current minimal UI behavior while repository mutations become authoritative.
3. Activate Firebase Auth/Firestore only with the correct `com.zarplus.app` configuration.
4. Implement real native scheduled notifications and real-device iOS validation.
5. Validate backup/restore and disaster-recovery flows before production use.
