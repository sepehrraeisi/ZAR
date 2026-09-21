# ZAR+ Server — راهنمای استقرار PocketBase

سرور اپ، یک فایل اجرایی «PocketBase» است: دیتابیس SQLite + احراز هویت ایمیل/پسورد + API.
هر سرور لینوکسی ارزان (1GB RAM کافی است) برای سال‌ها کافی است.

## ۱. آپلود فایل‌ها

روی سرور (SSH):

```bash
mkdir -p /opt/zar/server && cd /opt/zar/server

# آخرین نسخه PocketBase برای لینوکس (amd64) را دانلود کنید:
curl -L -o pb.zip \
  https://github.com/pocketbase/pocketbase/releases/download/v0.40.4/pocketbase_0.40.4_linux_amd64.zip
unzip pb.zip pocketbase.exe 2>/dev/null || unzip pb.zip
# فایل pocketbase باید کنار همین پوشه pb_migrations باشد:
#   /opt/zar/server/pocketbase
#   /opt/zar/server/pb_migrations/1758400000_zar_collections.js   (از این ریپو)
chmod +x pocketbase
```

پوشه `pb_migrations` را از این ریپو کنار فایل اجرایی کپی کنید — کالکشن‌ها و
قوانین دسترسی در اولین اجرا خودکار ساخته می‌شوند.

## ۲. اولین اجرا و حساب مدیر

```bash
cd /opt/zar/server
./pocketbase serve --http=0.0.0.0:8090

# در یک ترمینال دیگر، حساب مدیر سرور را بسازید:
./pocketbase superuser upsert ADMIN@YOUR.COM "A-Long-Password!"
```

از این لحظه:
- اپ‌ها به `http://SERVER_IP:8090` وصل می‌شوند
- پنل مدیریت در `http://SERVER_IP:8090/_/` است (فقط برای شما)

## ۳. اجرای دائمی (systemd)

```bash
cat >/etc/systemd/system/zar-server.service <<'UNIT'
[Unit]
Description=ZAR+ PocketBase server
After=network.target

[Service]
WorkingDirectory=/opt/zar/server
ExecStart=/opt/zar/server/pocketbase serve --http=0.0.0.0:8090
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable --now zar-server
```

## ۴. HTTPS (اختیاری ولی توصیه‌شده)

- اگر دامنه دارید: Caddy با یک رکورد A و دو خط config، گواهی خودکار می‌دهد.
- اگر ندارید: `cloudflared tunnel` (رایگان) آدرس HTTPS می‌دهد بدون باز کردن پورت.
- در هر دو حالت، آدرس نهایی را همان‌جا که اپ را می‌سازید به‌صورت
  `--dart-define=ZAR_SERVER_URL=https://YOUR-ADDRESS` پاس می‌دهید.

## ۵. بکاپ

همه‌ی داده‌ها یک فایل است: `pb_data_zar/data.db` (یا `pb_data/data.db`).
- کپی روزانهٔ خودکار همین فایل کافی است:
  `0 3 * * * sqlite3 /opt/zar/server/pb_data/data.db ".backup '/backups/zar-$(date +\%F).db'"`
- خروجی JSON قابل حمل هم از داخل خود اپ (بخش پشتیبان‌گیری) همیشه در دسترس است.

## ۶. ساخت اپ در حالت ابری

```powershell
flutter build apk --release `
  --dart-define=ZAR_SERVER_URL=https://YOUR-ADDRESS
```

ثبت‌نام اولین نفر (مالک فضای کاری) از داخل خود اپ انجام می‌شود؛ فضای کاری
هم به‌صورت خودکار ساخته می‌شود. اعضای بعدی را می‌توانید از پنل مدیریت سرور
(`zar_workspaces` → members) اضافه کنید.

## نکته‌های امنیتی

- قوانین کالکشن‌ها فقط اعضای همان فضای کاری اجازهٔ خواندن/نوشتن می‌دهند.
- ثبت‌نام عمومی باز است (برای رویboarding خودکار مالک)؛ اگر خواستید ببندید،
  در پنل مدیریت `users` → `createRule` را خالی بگذارید.
- هرگز فایل `pb_data` را عمومی نکنید؛ حساب superuser را فقط برای خودتان بسازید.
