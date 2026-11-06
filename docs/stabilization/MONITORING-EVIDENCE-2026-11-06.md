# Monitoring — Installation Evidence (Phase 2, §1)

تاریخ: 2026-11-06 — اجرا: GenCode با تأیید مالک — کاملاً self-hosted (بدون سرویس سوم)

## لایه ۱ — چکر داخلی روی VPS (هشدار ایمیلی واقعی)

- اسکریپت: `server/tools/zar_health_check.sh` → نصب‌شده `/usr/local/sbin/zar-health-check` (root:root 0755)
- یونیت‌ها: `zar-health-check.service` + `.timer` — هر ۱۰ دقیقه (`*:0/10`, Persistent) — نصب‌شده و enable
- چک‌ها (فقط خواندنی؛ هرگز repair نمی‌کند):
  1. active بودن `zar-server`, `caddy`, `zar-backup.timer`
  2. `127.0.0.1:8090/api/health` = 200
  3. listener پورت 8090 فقط loopback
  4. دیسک `/` زیر ۸۵٪
  5. عمر آخرین snapshot بکاپ < ۲۶ ساعت
  6. اعتبار گواهی TLS `app.titangold.ir` > ۱۴ روز
  7. `NRestarts` zar-server < ۳ (حلقه‌ی restart)
- هشدار: ایمیل به `raeisi.sep@gmail.com` از Postfix خود سرور (مسیر سلف‌هاست تأییدشده) + dedupe هر چک ۶ ساعت (`/var/lib/zar-health/last-alerts`)
- **تست مسیر هشدار end-to-end**: اجرای نسخه‌ی موقت با مسیر بکاپ نادرست → تشخیص + ارسال ایمیل (ایمیل تست/alert در Gmail مالک ارسال شد) + اصلاح باگ `date` و استقرار مجدد؛ اجرای سالم exit 0 silent
- اجرای زمان‌بندی‌شده فعال: last 19:20 UTC / next 19:30 UTC

## لایه ۲ — پروب بیرونی از PC مالک (best-effort)

- اسکریپت: `server/tools/zar_external_probe.ps1` → مستقر `C:\Users\simin\ZAR-Ops\zar_external_probe.ps1`
- Task Scheduler: `ZAR External Probe` هر ۱۵ دقیقه → `https://app.titangold.ir/api/health` (انتظار 200 + بدنه healthy)
- شکست: log `ZAR-Ops\external-probe.log` + پنجره‌ی هشدار ویندوز
- محدودیت: PC همیشه روشن نیست؛ این لایه مکمل چکر ایمیل VPS است، جایگزین آن نیست

## موارد باز (P1 ادامه‌ی مسیر)

1. پروب always-on واقعاً بیرونی نیاز به باکس دوم دارد (پیشنهاد: VPS ارزان دوم + uptime-kuma، یا سرویس uptime رایگان با رضایت مالک)
2. escalation/on-call فراتر از ایمیل — با تصمیم مالک
3. بررسی رمزنگاری at-rest (BitLocker) روی PC — نیاز به admin
4. PC در ساعت pull بکاپ (08:00) روشن باشد
