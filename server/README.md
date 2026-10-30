# ZAR+ Server — راهنمای امن استقرار PocketBase

این پوشه منبع حقیقت migrationها، ابزارهای recovery و templateهای عملیاتی سرور است. استقرار production باید فقط از commit بازبینی‌شده و با backup/restore/rollback ثبت‌شده انجام شود؛ اجرای مستقیم دستورهای آزمایشی روی production مجاز نیست.

نسخهٔ فعلی مبنا:

```text
PocketBase 0.40.4 linux/amd64
SHA-256: 14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a
```

## ساختار production

```text
/opt/zar/server/pocketbase        root:root 0755
/opt/zar/server/pb_migrations/    root:root 0755 (files 0644)
/opt/zar/server/pb_data/          zarapp:zarapp 0700 (files 0600)
```

- سرویس با حساب system و بدون login به نام `zarapp` اجرا می‌شود؛ هرگز با root اجرا نشود.
- PocketBase فقط روی `127.0.0.1:8090` گوش می‌دهد.
- Caddy تنها مسیر عمومی HTTPS است و به loopback reverse proxy می‌کند.
- پورت 8090 نباید روی IP عمومی باز باشد.

## آماده‌سازی artifact

باینری را از release رسمی بگیرید، hash و نسخه را قبل از نصب بررسی کنید و migrationها را بدون تغییر نام/تاریخ از همین commit کپی کنید. فایل migration اعمال‌شده را بازنویسی نکنید؛ هر اصلاح باید یک migration جدید و forward-only باشد.

```bash
/opt/zar/server/pocketbase --version
sha256sum /opt/zar/server/pocketbase
sha256sum /opt/zar/server/pb_migrations/*.js
```

قبل از اولین start:

1. حساب `zarapp` با password قفل‌شده و shell برابر `/usr/sbin/nologin` ایجاد شود.
2. فقط `pb_data` به `zarapp` واگذار شود؛ باینری و migrationها root-owned بمانند.
3. `server/deploy/zar-server.service` با `systemd-analyze verify` بررسی شود.
4. یک restore/canary ایزوله با همان unit و migrationها پاس شود.
5. سپس unit نصب، `daemon-reload` و start شود.

template نسخه‌شده:

```text
server/deploy/zar-server.service
```

شواهد deployment فعلی در این فایل‌هاست:

```text
docs/stabilization/POCKETBASE-SERVICE-HARDENING-PLAN.md
docs/stabilization/POCKETBASE-SERVICE-HARDENING-EVIDENCE-2026-10-30.md
```

## HTTPS و پنل مدیریت

Caddy باید به `127.0.0.1:8090` proxy کند. API و health از HTTPS عمومی تست می‌شوند، اما پنل `/_/` نباید بدون تصمیم و کنترل جداگانه در اینترنت رها شود. روش پیشنهادی عملیات، بستن `/_/` در Caddy و استفاده از SSH local forwarding برای دسترسی مدیر است؛ این تغییر باید plan/rollback مستقل داشته باشد.

هیچ اپ موبایل نباید مستقیماً به IP و پورت 8090 متصل شود. URL زمان build باید HTTPS باشد:

```powershell
flutter build apk --release `
  --dart-define=ZAR_SERVER_URL=https://YOUR-ADDRESS
```

## backup روزانه

از cron خطی یا کپی مستقیم فایل SQLite در زمان اجرا استفاده نکنید. artifactهای نسخه‌شده:

```text
server/tools/zar_backup.sh
server/deploy/zar-backup.service
server/deploy/zar-backup.timer
```

فرآیند deployment:

1. `/backups/zar-daily` را `0700 root:root` بسازید.
2. script را در `/usr/local/sbin/zar-backup` با `0750 root:root` نصب کنید.
3. unit/timer را با `0644 root:root` نصب و `systemd-analyze verify` کنید.
4. ابتدا `systemctl start zar-backup.service` را دستی اجرا کنید.
5. checksum، quick/integrity/schema، migrationها، countها و restore ایزوله را بررسی کنید.
6. فقط پس از pass شدن run دستی، timer را enable کنید.

هر snapshot به‌صورت یک دایرکتوری اتمیک منتشر می‌شود:

```text
/backups/zar-daily/zar-YYYYMMDDTHHMMSSZ/
  data.db
  SHA256SUMS
  METADATA
```

retention فعلی ۳۰ روز و حداقل ۷ snapshot موفق است. این backupها روی همان سرورند و جای backup مستقل/رمزشده را نمی‌گیرند. قبل از customer، دادهٔ مالی واقعی، launch یا 2026-11-30 باید استثنای موقت حذف شود.

راهنما و verifier:

```text
docs/stabilization/RESTORE-RUNBOOK.md
server/tools/verify_recovery_set.py
docs/stabilization/BACKUP-AUTOMATION-EVIDENCE-2026-10-30.md
```

## superuser و ثبت‌نام

- credential را در Git، مستندات، shell history یا پیام‌ها قرار ندهید.
- ساخت/چرخش superuser باید در پنجرهٔ عملیاتی کنترل‌شده و با ثبت evidence غیرحساس انجام شود.
- عمومی‌بودن signup یک تصمیم محصول/امنیت است و اکنون finding باز محسوب می‌شود؛ آن را از پنل به‌شکل ad hoc تغییر ندهید.
- bootstrap workspace باید در نهایت به command سروری atomic/idempotent منتقل شود؛ اتکای فعلی به چند درخواست client برای production-ready کافی نیست.

## گیت‌های پس از هر تغییر

- `PRAGMA quick_check` و `integrity_check` برابر `ok`.
- migration history، ruleها و countهای دامنه با baseline برابر.
- health داخلی و هر دو URL عمومی برابر HTTP 200.
- `NRestarts=0` و journal بدون خطای جدید.
- port 8090 از بیرون بسته و listener فقط loopback.
- backup جدید checksum/restore/reconciliation را پاس کند.
- rollback artifact و handoff به‌روز شوند.
