# Incident Runbook — ZAR+

وقتی ایمیل هشدار از `noreply@titangold.ir` رسید یا کاربر خرابی دید، این ماتریس را اجرا کن. اصل ثابت: **اول evidence، بعد action؛ هیچ repair دستی روی داده.**

## اتصال اضطراری

```powershell
ssh zar-vps
sudo -n systemctl status zar-server --no-pager
curl -s http://127.0.0.1:8090/api/health
sudo -n journalctl -u zar-server -n 50 --no-pager   # خروجی را محدود نگه دار
sudo -n /usr/local/sbin/zar-health-check; echo $?   # اجرای دستی چکر
```

## ماتریس هشدار → اقدام

| هشدار | اقدام فوری | برگشت به سرویس |
|---|---|---|
| `zar-server.service: unit is failed` | `journalctl -u zar-server -n 100` → علت؛ اگر پیکربندی: `systemd-analyze verify` | `sudo -n systemctl start zar-server`؛ health + NRestarts |
| `health-endpoint` (غیر 200) | listener و DB ببین (`ss -tln`)؛ لاگ PB | start سرویس؛ اگر تکرار شد → containment: stop و باید باگ مشخص شود |
| `listener` (8090 غیر loopback) | **بحرانی** — فوراً `systemctl restart zar-server`؛ منبع را پیدا کن (unit overlay دست‌خورده؟) | بعد از پایداری: postflight listener |
| `disk` ≥ ۸۵٪ | بزرگ‌ترین مصرف‌کننده: `du -x` روی /var/log و /backups | retention بکاپ‌ها را کم نکن؛ فایل‌های لاگ بچرخان |
| `backup` (عمر > ۲۶ ساعت) | `systemctl status zar-backup.timer` + اجرای دستی `sudo -n /usr/local/sbin/zar-backup`؛ بعد pull آفلاین | تا سالم شدن بکاپ: از ورود داده‌ی سنگین پرهیز کن |
| `tls` (< ۱۴ روز) | Caddy معمولاً خودش تمدید می‌کند؛ `systemctl restart caddy` و لاگش را ببین | — |
| `restarts` (NRestarts ≥ ۳) | حلقه: `journalctl` → علت (migration/hook جدید؟) | در صورت مشکوک‌بودن به hook جدید: مسیر containment طبق `TRANSACTIONAL-RESTORE-PLAN.md` (route hook را معوق کن، forward-only) |

## خرابی کامل (سرویس/دیتابیس)

1. `docs/stabilization/RESTORE-RUNBOOK.md` را باز کن — تنها مرجع مجاز بازیابی
2. snapshot انتخابی: آخرین `zar-*` سالم (SHA256SUMS + quick_check)؛ کپی off-site روی PC هم هست (`ZAR-OffsiteBackups`)
3. **ممنوع:** direct edit روی SQLite، destructive restore روی production، `migrate down` پس از هر receipt

## ثبت و پیگیری

- هر رخداد: زمان UTC، هشدار، اقدام، نتیجه → `HANDOFF.md` §0 + یک خط در `FINDINGS.md`
- پس از پایداری: `zar-health-check` را دستی اجرا کن تا exit 0
