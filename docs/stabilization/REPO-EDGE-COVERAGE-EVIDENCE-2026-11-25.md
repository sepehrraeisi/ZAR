# PocketBase repository edge coverage (P2)

تاریخ: 2026-11-25 — شاخه: `feature/pocketbase-repository-edge-coverage`

## Suite

`test/zar_pocketbase_repository_edge_test.dart` (alongside the main CAS suite):

**appendCashEntry**
- POSTs `/api/zar/write/cash/append` with workspace + 32-char idempotency key
- identical existing id → no-op (no append call)
- mutated payload for existing id → `StateError`
- 409 `cash_entry_immutable` / `idempotency_payload_mismatch` → typed conflict

**savePaymentAllocations**
- mismatched `settlementId` → `FormatException`
- POSTs `/api/zar/write/allocations/replace` with `expectedBefore`
- 409 `stale_allocation_set` → typed conflict

**archivePerson**
- CAS upsert with `archived: true`

## Local

```text
flutter test test/zar_pocketbase_repository_edge_test.dart
→ All tests passed!
```

## Status

Closes the remaining «repository edge cases» P2 coverage gap called out after
auth / cloud-shell / backup-UI slices.
