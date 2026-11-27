# Multi-device physical soak — Evidence (2026-11-27)

Gate: `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md` (ZAR-DATA-002 physical)

## Environment

| | |
|--|--|
| Devices | A = Samsung `SM_N986U` / `R5CN70SG2BF`; B = moto e13 / `ZY22HS8MV4` |
| APK | **20084** for create/sync/terminal/cancel/airplane; **20085** for note-refresh verify |
| Signer | `d19ad112…2667` |
| Workspace | گالری طلای مهر / `shahab@zarplus.cloud` → `https://app.titangold.ir` |
| Observer | agent + owner (dual USB 2026-11-27; prior one-cable 2026-11-25) |
| Master tip at close | after PR #82 (`DEVICE-QA-APK-20085-…`) |

## Checklist results

| Step | Result | Notes |
|------|--------|-------|
| 1 Baseline | Pass | Both on same workspace; people counts aligned |
| 2 Create sync | Pass | B→A person create (2026-11-25); A→B `SoakAirA214710` during B airplane (2026-11-27) |
| 3 Conflict | Partial | CAS/reload path exists; same-account two-device still looks identical in resume (`createdBy=userId` only). ADR #80 Option B proposed |
| 4 Terminal freeze | Pass | A complete مهیار USD 1000 → B `۰ تعهد باز` + read-only closed banner |
| 5 Cash | Skipped | Not exercised this window (device-local vs cloud cash noted in checklist) |
| 6 Airplane | Pass | B airplane ~60s + A write; B catch-up without duplicate |
| 7 Resume | Pass | B force-stop → relaunch; session + data intact |

## Follow-on (APK 20085)

In-sheet settlement یادداشت refresh (PR #81) verified on both devices after install
(`DEVICE-QA-APK-20085-EVIDENCE-2026-11-27.md`).

## Pass criteria vs advertising

- No silent last-write-wins observed in exercised paths; conflicts remain CAS-visible.
- No duplicate people/settlements from airplane/resume.
- No P0/P1 attributable to ZAR+ in the window.
- **Advertising cloud multi-device reliability:** still gated on owner decision for
  device attribution (ADR #80) so conflict/resume UX can name which phone wrote —
  engineering soak of sync/lifecycle/airplane is otherwise green on 20085.

## Artifacts

Local soak log / screenshots under `.tmp-soak/` (not committed).
