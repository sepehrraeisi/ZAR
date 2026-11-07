# Off-site Backup — Installation Evidence (Phase 1, §10.3)

تاریخ: 2026-11-06 — اجرا: GenCode با تأیید مالک
هدف: حذف استثنای «بکاپ صرفاً same-host» قبل از customer data / launch / **2026-11-30** (تاریخ تحقق: ۱۴ نوامبر زودتر از ددلاین)

## معماری

```text
VPS /backups/zar-daily/zar-*.json (03:00 UTC timer, atomic)
  → SSH pull (zaradmin, sudo -n cat — read-only روی سرور)
  → PC مالک: C:\Users\simin\Documents\ZAR-OffsiteBackups\zar-<TS>\
  → راستی‌آزمایی خودکار: SHA-256 در برابر SHA256SUMS سرور + SQLite quick_check
  → retention محلی: ۱۴ snapshot آخر + pull-log.txt + last-pull-status.json
```

- اسکریپت (source of truth): `server/tools/pull-offsite-backups.ps1`
- نسخه‌ی مستقر برای Task Scheduler (به‌دلیل فاصله در مسیر ریپو): `C:\Users\simin\ZAR-Ops\pull-offsite-backups.ps1`
- هیچ تغییری روی سرور انجام نمی‌شود (فقط sudo cat خواندنی)

## زمان‌بندی

- Task name: `ZAR Offsite Backup Pull` — daily **08:00** local (بعد از تکمیل بکاپ 03:00 UTC = 06:30 Tehran)
- ساخت با schtasks موفق؛ اجرای آزمایشی از کانتکست Task Scheduler: `ok:true` (idempotent — تکرار pull نمی‌کند)

## شواهد اجرای اول (2026-11-06)

- هر **۱۰ snapshot موجود** (از `zar-20261030T200252Z` تا `zar-20261106T030011Z`) دانلود شد
- برای تک‌تک آن‌ها: `SHA256SUMS` سرور مطابقت داده شد (byte-identical) و `PRAGMA quick_check` روی `data.db` برابر `ok`
- لاگ کامل: `ZAR-OffsiteBackups\pull-log.txt` — وضعیت: `last-pull-status.json`

## RPO / RTO و بازیابی

- **RPO عملیاتی: ۲۴ ساعت** (برابر بکاپ شبانه سرور؛ بکاپ‌های دستی/رویدادی جداگانه اضافه می‌شوند)
- **RTO:** برگرداندن snapshot انتخابی به سرور طبق `docs/stabilization/RESTORE-RUNBOOK.md`؛ فایل‌های محلی بایت‌به‌بایت همان آرتیفکت‌های سرورند، پس drill قبلی clone restore (run 0004) برای همین محتوا معتبر است
- دومین اپراتور: اسکریپت را اپراتور دوم می‌تواند اجرا کند (فقط SSH alias لازم است)؛ drill کامل بازیابی از نسخه‌ی آفلاین در مرحله بعد ثبت می‌شود

## موارد باز (ثبت‌شده)

1. رمزنگاری مقصد: بررسی فعال‌بودن Device encryption/BitLocker روی C: به مجوز admin نیاز دارد — مالک از Settings → Device encryption بررسی/فعال کند (انتقال SSH رمزنگاری‌شده است؛ at-rest پیشنهاد می‌شود فعال باشد)
2. مقصد فیزیکی دوم (هارد اکسترنال ادواری): توصیه می‌شود؛ اسکریپت قابل تخصیص به درایو دوم است
3. اگر PC در ساعت 08:00 روشن نباشد، آن روز skip می‌شود (run بعدی فردا) — alert خودکار در فاز مانیتورینگ (Phase 2) اضافه می‌شود
4. استثنای `TEMPORARY-RECOVERY-EXCEPTION.md` با این پیاده‌سازی عملاً برطرف شد؛ نسخه‌بندی/به‌روزرسانی آن سند همراه PR این شواهد

## Restore Drill دوم — از کپی آفلاین (2026-11-07، اپراتور: GenCode)

هدف: اثبات این‌که اپراتور دوم بدون دسترسی به سرور می‌تواند از کپی آفلاین یک سرویس سالم بالا بیاورد.

- منبع: `ZAR-OffsiteBackups/zar-20261107T083703Z/data.db` — SHA-256 `ef914b9e…c5eac` برابر `SHA256SUMS` سرور (بایت‌به‌بایت)
- مقایسه با production زنده: تعداد ردیف‌ها دقیقاً یکسان (users 1 / workspaces 1 / people 1 / deals 0 / settlements 1 / cash_entries 0 / receipts 0)؛ تنها اختلاف: ۱ مهاجرت (`1793604700` که بعد از این بکاپ deploy شد) — مورد انتظار
- اجرا: PocketBase 0.40.4 لوکال روی کپی بازیابی‌شده → health **200** در ~۱۳ ثانیه (RTO محلی)؛ **ورود واقعی** با اکانت تست موفق و `zar_people` با workspace-scoped query برگشت داده شد
- نتیجه: زنجیره‌ی کامل «سرور → آفلاین → بازیابی → دسترسی به داده» توسط اپراتور دوم اثبات شد؛ بند «اجرا توسط اپراتور دوم» فاز ۳ بسته شد
