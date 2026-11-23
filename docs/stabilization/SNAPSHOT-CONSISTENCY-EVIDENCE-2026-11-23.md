# Consistent workspace snapshot read — Evidence (ZAR-DATA-006)

تاریخ: 2026-11-23 — شاخه: `feature/consistent-snapshot-read`
مرجع: FINDINGS ZAR-DATA-006؛ gate multi-device پس از write CAS

## Scope

- فیلد `epoch` روی `zar_workspaces` (migration `1793604703`)
- bump epoch داخل همان transaction برای upsert / allocation replace / cash append / restore commit
- مسیر `GET /api/zar/read/snapshot` با fence قبل/بعد epoch و retry محدود
- کلاینت: `ZarPocketBaseRepository.loadCompleteSnapshot` فقط از این route

## Acceptance

- `pocketbase_snapshot_consistency_test.py`: anonymous 401؛ epoch بعد از write؛
  خواندن هم‌زمان با writer هرگز note/revision مخلوط نمی‌دهد
- Flutter repository tests با fake snapshot route
- lineage شامل `1793604703`؛ restore helper hash به‌روز

## Production

- Deploy فقط بعد از CI سبز + backup تازه (migration + hooks).
