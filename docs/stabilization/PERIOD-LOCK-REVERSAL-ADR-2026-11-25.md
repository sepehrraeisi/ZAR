# ADR — Period lock + reversal-only correction (ZAR-DATA-008 remainder)

تاریخ: 2026-11-25  
وضعیت: **Proposed — needs accountant + owner sign-off** (no server mutate yet)

## Context

- Terminal deal/settlement status cannot leave `completed`/`cancelled`
  (`lifecycle_locked`).
- Field freeze: only `note` / `updatedAt` mutable on terminal rows
  (`terminal_field_locked`).
- Still open: closing an accounting **period**, and correcting posted history
  only via **reversal** rows (not in-place rewrite).

## Proposed model (engineering draft)

1. **Period** — workspace-scoped `{id, label, startsAt, endsAt, lockedAt,
   lockedBy}`. While a period is locked, create/update of deals/settlements/
   cash whose `occurredAt`/`createdAt` falls inside the period is rejected
   (`409 period_locked`) except note-only on already-terminal rows.
2. **Reversal** — new deal/settlement/cash row with `reversesId` pointing at
   the posted row; amounts negated; original stays immutable. UI shows
   «برگشت» not «ویرایش».
3. **Unlock** — only via forward migration / admin ops with audit reason;
   not a normal shopkeeper action.

## Out of scope until accountant OK

- Full GL / chart of accounts / tax / P&L (product boundary)
- Automatic fiscal calendar

## Decision needed

- Approve period + reversal shape above?
- Who may lock a period (owner only vs any workspace member)?
- Retention of reversed originals?

## Next after approval

Forward migration + `/api/zar/write/*` gates + Flutter UI + evidence suite.
