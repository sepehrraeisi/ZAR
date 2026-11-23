# Public signup policy — CLOSED (§10.4)

تاریخ: 2026-11-23 — شاخه: `feature/close-public-signup`
سیاست: `zar.signup.public=closed` (تا لانچ)

## Decision

Owner/roadmap: ثبت‌نام عمومی تا انتشار بسته می‌ماند. این migration آن را
**server-enforced** و versioned می‌کند؛ UI هم toggle ساخت حساب را مخفی می‌کند.

## Server

- migration `1793604702_close_public_signup.js` → `users.createRule = null`
- down-migration هم مرز را باز نمی‌کند (مثل قفل حذف workspace)
- seeding فقط با superuser (CLI / admin API)

## Client

- `ZarAuthGate` دیگر `onSignUp` به `LoginScreen` نمی‌دهد → دکمه ساخت حساب دیده نمی‌شود

## Acceptance

- `pocketbase_signup_policy_test.py`: anonymous create 403؛ abuse همچنان deny؛
  admin seed + auth + bootstrap 200
- تمام suites که قبلاً public signup می‌کردند از helper ادمین استفاده می‌کنند
- lineage + canary hashes به‌روز
- `flutter analyze`

## Production deploy (2026-11-23)

- PR #32 merged (`19e1a57`); required CI checks green.
- Fresh atomic backup `zar-20261123T143904Z` (`data.db` SHA-256 `3d497442…6c2c`, quick/integrity ok) + off-site byte-identical under `Documents\ZAR-OffsiteBackups\zar-20261123T143904Z`.
- stop → Applied `1793604702_close_public_signup.js` as `zarapp` → start.
- Postflight: `zar-server`/`caddy`/`zar-backup.timer` active; health `200`; `NRestarts=0`; listener `127.0.0.1:8090` only.
- Schema: `users.createRule` is SQL `NULL`; anonymous `POST /api/collections/users/records` → **403** (`Only superusers can perform this action.`).
- Host artifact SHA-256: migration `d68d39ce…5973` (installed copy).

باز کردن signup = migration جدید رو به جلو + abuse/rate-limit evidence جدا.
