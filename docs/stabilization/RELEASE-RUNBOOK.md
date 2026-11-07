# Release Runbook — ZAR+ (the "update loop")

هر آپدیت برنامه با همین گردکار منتشر می‌شود. مالک/اپراتور: same person یا اپراتور ثابت.

## ۰. پیش‌نیازهای یک‌بارکه (status: done)

- release keystore: `C:\Users\simin\Documents\ZAR-Signing\zar-release.jks` + `credentials.txt` (گواهی SHA-256 `d19ad112…2667`) — نسخه پشتیبان `ZAR-Ops`
- `android/key.properties` روی ماشین build موجود (git-ignored)
- master محافظت‌شده: ۴ چک اجباری؛ هر تغییر = branch → CI → PR → merge

## ۱. تغییر کد/وابستگی

1. branch جدید از master
2. تغییرات + تست؛ `flutter analyze --no-fatal-infos` و `flutter test` سبز لوکال
3. push → CI سبز (۵ چک) → merge PR
4. اگر migration سرور دارد: فقط فایل نسخه‌دار جدید؛ هیچ‌گاه migration قبلی را تغییر نده

## ۲. بیلد و راستی‌آزمایی

```powershell
flutter build apk --release --split-per-abi --target-platform android-arm64 `
  --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=<N+1>
```

- versionCode نصب‌شده = build-number **+ 2000** (آفست پروژه) — همیشه صعودی
- `apksigner verify --print-certs` → گواهی باید دقیقاً `d19ad112…2667` باشد
- `sha256sum` خروجی را ثبت کن

## ۳. نصب و تست دستگاه

- `adb install -r` (release→release بدون پاک شدن داده)
- ورود/سشن، صندوق، یک عملیات واقعی، اسکرین‌شات

## ۴. انتشار

1. tag `vX.Y.Z(-rcN)` روی commit دقیق build + push
2. GitHub Release (pre-release تا RC نهایی) با APK + `SHA256SUMS.txt`
3. یادداشت release: commit، versionCode، هش APK، تغییرات

## ۵. اگر تغییرات سمت سرور هم هست

- بدون fresh atomic backup + کپی off-site + راستی‌آزمایی، deploy ممنوع
- migration فقط نسخه‌دار؛ **هیچ‌گاه migration پایین‌تر از `1793604800_transactional_restore.js` را down نکن** (پس از اولین receipt: فقط forward-only)
- ترتیب: stop → `migrate up` صریح با `--dir`/`--migrationsDir` → راستی‌آزمایی schema → start → postflight (health، NRestarts=0، listener، دقیقه ۰/۵/۱۵)
- برای مهاجرت‌های جدید: **هرگز بالای `1793604800` شماره نزن** (تست refuse-down restore به lineage حساس است) — شماره‌ی `17936047xx` بگیر

## ۶. به‌روزرسانی اسناد

- `HANDOFF.md` §0 (post-handoff log) + در صورت تغییر رفتار: evidence doc مربوطه
