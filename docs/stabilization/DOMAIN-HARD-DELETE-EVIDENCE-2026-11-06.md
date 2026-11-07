# Domain Hard-Delete Invariant — Evidence (Phase 2, §10.5 increment)

تاریخ: 2026-11-06 — اجرا: GenCode با تأیید مالک
مرجع: `PROGRAMMER-HANDOFF.md` §10.5 «حذف hard-delete از باقی history/financial collections»

## تغییر

- migration `server/pb_migrations/1794000000_lock_domain_hard_delete.js`:
  `deleteRule = null` (فقط superuser) برای `zar_people`, `zar_deals`, `zar_settlements`, `zar_coin_types`, `zar_currency_types`
- down migration قوانین memberRule را بازمی‌گرداند (خارج از workstream receipt-guarded restore؛ مستقل است)

## چرا این پنج‌تا و چرا `zar_allocations` نه

- client هرگز این ردیف‌ها را delete نمی‌کند (فقط upsert + reversal) — `rg` روی کل `lib/` تنها یک DELETE در مسیر allocations پیدا کرد
- `zar_allocations` عمداً معاف ماند: جریان ویرایش تخصیص‌ها replace اتمیک است (delete + create در یک batch). بستن آن نیازمند طراحی سمت سرور جداگانه است — open item
- `zar_cash_entries` از قبل قفل بود (`1793347200`)؛ `zar_workspaces` deleteRule خالی و members immutability با `1793604800` بسته شده بود

## شواهد واقعی PocketBase (`pocketbase_domain_hard_delete_test.py`)

- migrate up → down 1 → up: پاس (lineage سالم)
- member person/deal hard-delete: **403** ✅
- anonymous person hard-delete: **403** ✅
- رکورد پس از تلاش حذف: سالم ✅
- create/settlement/allocation: کار می‌کند و delete allocation همچنان **204** (جریان replace client سالم) ✅
- رگرسیون: `pocketbase_authz_test.py` کامل پاس (cash locks، workspace locks، reversal create) ✅

## ثبت در CI

- `phase_a2_ci.yml` → job `pocketbase-authorization` حالا `pocketbase_domain_hard_delete_test.py` را هم اجرا می‌کند

## استقرار روی production (2026-11-07)

- fresh atomic backup `zar-20261107T083703Z` (SHA `ef914b9e…c5eac`، quick_check ok) + کپی off-site تأییدشده
- migration فایل با root:root 0644 در `/opt/zar/server/pb_migrations` نصب؛ سرویس stop → `migrate up` صریح (`Applied 1793604700_lock_domain_hard_delete.js`) → start
- postflight: active، health 200، `NRestarts=0`؛ schema `_collections`: پنج کالکشن `deleteRule=null`، `zar_allocations` memberRule (دست‌نخورده)
- ردیف مهاجرت در `_migrations` ثبت شد (restore migration همچنان بالای lineage باقی ماند — migration جدید با پیش‌شماره `1793604700` زیر آن قرار گرفت تا فرض‌های تست refuse-down restore حفظ شود)

## مانده‌ی §10.5 (open، مستند)

- CAS/idempotency برای writeهای معمولی (restore path کامل دارد؛ writeهای upsert تکی فعلاً بدون CAS — طراحی سمت سرور جداگانه می‌خواهد)
- جایگزینی flow حذف+ساخت `zar_allocations` با عملیات سروری دارای audit-linkage
- workspace bootstrap اتمیک/idempotent در سطح سرور
