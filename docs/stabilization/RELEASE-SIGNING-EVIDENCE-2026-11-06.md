# Android Release Signing — Installation Evidence (Phase 1, §10.2)

تاریخ: 2026-11-06 — اجرا: GenCode با تأیید مالک
پیش‌نیاز: پیکربندی `android/app/build.gradle.kts` از قبل release signing را از `android/key.properties` می‌خواند و در نبود آن، build release را با GradleException رد می‌کند (هرگز fallback به debug نمی‌شود).

## Keystore

- مسیر (خارج از ریپو): `C:\Users\simin\Documents\ZAR-Signing\zar-release.jks` (PKCS12، RSA 4096، اعتبار 10,000 روز)
- Alias: `zarplus-release`
- DN: `CN=ZAR Plus, OU=ZAR, O=sepehrraeisi, L=Tehran, C=IR`
- **گواهی SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`**
- رمزها: `C:\Users\simin\Documents\ZAR-Signing\credentials.txt` (در chat/گیت/سند منتشر نمی‌شود)
- نسخه‌های پشتیبان: `C:\Users\simin\ZAR-Ops\zar-release.jks.bak` + `key.properties`
- Git: `android/key.properties` و `*.jks`/`*.keystore` در `.gitignore` هستند و در `git status` ظاهر نمی‌شوند (تست شد)

## بیلد امضاشده (اولین release artifact)

- دستور: `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ZAR_SERVER_URL=https://app.titangold.ir --build-number=16080`
- خروجی: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (24.3MB)
- **APK SHA-256: `a38449853d36e677d3df46a279de91f2dcfdd7e2efa39eb7805c33f5cf0f2e5a`**
- package: `com.zarplus.app` — versionCode: **18080** — versionName: `1.0.0`
- امضا (apksigner verify): `CN=ZAR Plus...` با گواهی SHA-256 بالا — **تطبیق بایت‌به‌بایت با keystore** ✅ (دیگر debug key نیست)
- icon tree-shaking فعال (Cupertino 96.6%، Material 99.7% کاهش)

## گردکار نسخه‌های بعدی

1. `--build-number` جدید (> 16080) — versionCode نصب‌شده = build-number + 2000
2. build از `android/key.properties` (روی این ماشین موجود است)
3. `apksigner verify --print-certs` + مقایسه گواهی با همین سند
4. tag نسخه + ثبت در `HANDOFF.md`

## گذار گوشی از debug به release

- نصب release روی گوشی که debug نصب دارد → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`؛ نیاز به uninstall (پاک شدن داده‌ی local) و سپس نصب
- داده‌ی workspace ابری محفوظ است؛ داده‌ی local پس از ورود دوباره همگام می‌شود. توصیه: پیش از uninstall یک «ساخت و ذخیره نسخه پشتیبان» محلی بگیرید (فایل بیرون اپ می‌ماند)
- تا تأیید مالک، گوشی روی build 16079 (debug) مانده است

## باز (P1)

- custody آفلاین دوم برای keystore/رمز (مثلاً درایو خارجی یا چاپ در گاوصندوق) — در Controlهای نگهداری ثبت شود
- signed reproducible build کامل (SBOM/provenance) — فاز ۲ supply chain
