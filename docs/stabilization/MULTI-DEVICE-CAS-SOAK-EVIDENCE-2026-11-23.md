# Multi-device concurrent CAS soak — Evidence

تاریخ: 2026-11-23 — شاخه: `feature/multi-device-cas-soak`
مرجع: gate تبلیغ multi-device پس از §10.5 / §10.4

## Scope

- دو session هم‌زمان برای یک owner (= دو دستگاه)
- race روی `POST /api/zar/write/upsert` (person) → یک 200 / یک 409 با
  `stale_revision` + `currentRevision`
- race روی `POST /api/zar/write/allocations/replace` → یک 200 / یک 409 با
  `stale_allocation_set`
- appendهای cash با idهای متمایز هم‌زمان → هر دو 200 و هر دو ردیف ماندگار
- Progress (2026-11-25): after seed, device A/B snapshots share the same
  workspace `epoch` and person row; device B workspace Record peek matches
  (covers the cheap epoch probe used by the client watcher).

## Server / tests

- `server/tests/pocketbase_multi_device_cas_soak_test.py`
- wired in `.github/workflows/phase_a2_ci.yml` (`pocketbase-authorization`)

## Out of scope

- دستگاه فیزیکی / UI realtime (see `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`)
- باز کردن public signup
- تغییر schema یا hooks production (تست‌only)

## Acceptance

- suite محلی سبز روی PocketBase 0.40.4
- CI `pocketbase-authorization` شامل این suite
