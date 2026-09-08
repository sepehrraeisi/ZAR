# Codex handoff — 2026-09-02

Branch: `codex/phase-a2-ux`

## Product constraints

ZAR+ remains an operational assistant for gold/currency/coin dealers. Do not add profit/loss, accounting ledger, tax, cost basis, or financial statements.

## Work completed while Codex usage was unavailable

### Deal-aware operational inventory

The inventory projector now includes non-cancelled Deals:

- Buy increases the operational position.
- Sell decreases the operational position.
- Cancelled deals do not affect the position.
- Open Settlements remain pending only.
- Completed standalone Settlements still affect the position.
- A completed Settlement linked to a non-cancelled Deal is not applied a second time.

This fixes the user-reported case where recording a USD purchase did not increase USD holdings.

Dashboard now passes both Deals and Settlements into the inventory projector.

Inventory movement records can originate from Deal or Settlement and the detail UI labels them as:

- خرید از
- فروش به
- دریافت از
- تحویل به

A backward-compatible `onOpenSettlement` alias remains temporarily on `OperationalInventoryScreen` so the existing repository shell can compile until it is migrated to `onOpenRecord`.

### Daily operational report

Added typed `ZarOperationalDailyReportProjector` with:

- buys for selected day
- sells for selected day
- completed receives for selected day
- completed deliveries for selected day
- open obligations due on selected day
- currently-open obligations already overdue before selected day

No cross-asset totals, valuation, profit/loss, or accounting concepts are calculated.

Added `OperationalDailyReportScreen` with Jalali date navigation, operational summary counts, and separated activity sections.

## Required Codex follow-up

1. Review all commits after validated head `d4c640efeb82de1b7a206f30e8d831208a03cec3`.
2. Run `dart format` on changed/new Dart files.
3. Run `flutter analyze --no-pub`.
4. Run full `flutter test --no-pub`.
5. Fix any compile/test issues without reverting deal-aware inventory semantics.
6. In `repository_phase_a2_app_v2.dart`, migrate `_openInventory()` to:
   - pass `deals: _store.deals`
   - pass `settlements: _store.settlements`
   - use `onOpenRecord` (the compatibility alias can then be removed later).
7. Wire `OperationalDailyReportScreen` into the live repository shell using a minimally disruptive Home or settings entry. Do not change the 5-tab navigation.
8. Verify Daily Report record IDs resolve to current `AppRecord` presentation records for Deal and Settlement rows.
9. Build Windows release.
10. Build Android ARM64 release with build number > 2007.
11. Upgrade-install on Samsung S20 Ultra without uninstalling.
12. Device validation:
    - create a USD Buy Deal and confirm USD holdings increase immediately
    - create a USD Sell Deal and confirm holdings decrease
    - verify linked Settlement completion does not double-count
    - verify standalone receive/deliver still moves inventory
    - open inventory movement detail for a Deal
    - open daily report, change Jalali day, open Deal/Settlement details
    - force-stop/restart and verify same projection
    - check logcat for Flutter/AndroidRuntime fatal errors

## Important semantic note

The current user requirement is that a registered Buy/Sell Deal changes the operational asset position immediately. This intentionally differs from the earlier Phase 4 rule that only completed physical Settlements affected inventory. Preserve the new behavior unless the user explicitly changes this requirement.
