# ZAR+ Firebase Schema (Pre-Integration Contract)

Firebase is intentionally not connected to the Flutter client yet. This document defines the storage contract so UI/business logic can stabilize before credentials are introduced.

## Core principles

- Firestore is the cloud source of truth for business records.
- Every operational document lives under a `businessId` workspace.
- Jalali is presentation/input only. Firestore stores canonical timestamps.
- Gold decimal quantities are stored as decimal strings, not binary floating point.
- Currency totals are stored in integer minor units where the currency uses them.
- Completed/cancelled history is preserved; normal workflow does not hard-delete financial records.
- Archive hides a person from the active list but never deletes their history.
- Audit logs are append-only from the normal client perspective.
- Reminder documents are structured data, independent from notification delivery implementation.

## Collections

### `users/{uid}`

```json
{
  "displayName": "...",
  "email": "...",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `businesses/{businessId}`

```json
{
  "name": "ZAR+ Workspace",
  "ownerUid": "uid",
  "timezone": "Asia/Tehran",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `businesses/{businessId}/memberships/{uid}`

```json
{
  "role": "owner | staff",
  "createdAt": "Timestamp"
}
```

### `businesses/{businessId}/people/{personId}`

```json
{
  "displayName": "علی رضایی",
  "normalizedName": "علی رضایی",
  "phone": "09121234567",
  "note": "optional",
  "archived": false,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "createdBy": "uid"
}
```

`phone` is optional. `archived=true` never removes linked records.

### `businesses/{businessId}/deals/{dealId}`

```json
{
  "dealType": "buy | sell",
  "assetType": "gold | currency",
  "personId": "personId",
  "dealAt": "Timestamp",
  "status": "active | completed | cancelled",

  "goldWeightDecimal": "1000.000",
  "goldUnit": "gram",
  "goldPurity": "optional",

  "currencyCode": "USD",
  "currencyMinorUnits": 2000000,

  "note": "optional",
  "createdBy": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Only fields relevant to the selected asset are present.

### `businesses/{businessId}/settlements/{settlementId}`

```json
{
  "dealId": "optional dealId",
  "personId": "personId",
  "direction": "receive | deliver",
  "assetType": "gold | currency",
  "status": "open | completed | cancelled",
  "scheduledAt": "Timestamp",
  "hasTime": true,
  "completedAt": "Timestamp | null",
  "completedBy": "uid | null",

  "goldWeightDecimal": "300.000",
  "goldUnit": "gram",
  "goldPurity": "optional",

  "currencyCode": "USD",
  "currencyMinorUnits": 1000000,

  "note": "optional",
  "createdBy": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

A settlement can exist without a deal. This is required for direct operational entries such as “tomorrow receive 350 g from Ali.”

### `businesses/{businessId}/reminders/{reminderId}`

```json
{
  "recordId": "settlementId",
  "recordType": "settlement",
  "ruleType": "offset | custom",
  "minutesBefore": 60,
  "customAt": "Timestamp | null",
  "enabled": true,
  "lastScheduledAt": "Timestamp | null",
  "lastDeliveredAt": "Timestamp | null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Snooze should be represented explicitly (for example a new custom reminder occurrence or a `snoozedUntil` field), not by changing the settlement due date.

### `businesses/{businessId}/auditLogs/{auditId}`

```json
{
  "recordId": "recordId",
  "recordType": "deal | settlement | person",
  "action": "create | edit | complete | cancel | archive | restore",
  "actorUid": "uid",
  "createdAt": "Timestamp",
  "before": {},
  "after": {}
}
```

Normal clients may create audit rows but may not update/delete them.

### `businesses/{businessId}/settings/general`

```json
{
  "timezone": "Asia/Tehran",
  "defaultReminderMinutes": 60,
  "defaultSnoozeMinutes": 30,
  "notificationPrivacy": "limited",
  "notificationSoundProfile": "systemDefault",
  "updatedAt": "Timestamp"
}
```

Device-specific preferences can remain local if they should not sync across devices.

## Required query patterns

Home:
- open settlements ordered by `scheduledAt`, scoped to a narrow operational date range
- overdue: `status == open` and `scheduledAt < now`

Calendar:
- settlements within selected Gregorian timestamp range representing the Jalali month/day

Person detail:
- settlements by `personId`, status/date ordered
- deals by `personId`, date ordered

History:
- completed/cancelled settlements, paginated by date

Audit:
- logs by `recordId`, newest first

## Security expectations

`firestore.rules` must guarantee:
- unauthenticated access fails
- membership in Business A cannot read Business B
- staff can perform normal operational reads/writes
- owner-only administrative settings/membership changes
- no normal hard delete for people/deals/settlements
- audit logs cannot be modified/deleted by normal clients

## Integration order

1. Create Firebase app entries using final package identity `com.zarplus.app`.
2. Enable Email/Password Authentication.
3. Create Firestore in production mode (not permanent Test Mode).
4. Deploy `firestore.rules` and `firestore.indexes.json`.
5. Add FlutterFire packages/configuration.
6. Implement repository adapters behind domain interfaces.
7. Migrate mock state to Firestore-backed state.
8. Test account recovery/new-device behavior.
9. Add native notification delivery adapter.
10. Only then treat ZAR+ as production-ready for sensitive business records.
