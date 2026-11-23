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

## Production

- Deploy فقط بعد از CI سبز + backup تازه.
- باز کردن signup = migration جدید رو به جلو + abuse/rate-limit evidence جدا.
