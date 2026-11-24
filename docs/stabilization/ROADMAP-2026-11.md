# ZAR+ — Roadmap اجرایی تا «فقط آپدیت»

تاریخ تصویب: 2026-11-06 — تصویب‌کننده: مالک محصول
مرجع: `docs/stabilization/PROGRAMMER-HANDOFF.md`

## تصمیمات مالک (ثبت‌شده)

1. **PR #3 merge شد** — master از `e60d68d` به `725c8fa` (merge commit) رسید؛ tag پایه: `stabilization-baseline` (روی head شاخه، `2ebd9d8`).
2. **بازیابی تراکنشی**: بعد از اتمام فاز ۱، در maintenance window اختصاصی deploy می‌شود (پنجره، اپراتور و rollback owner قبل از اجرا مشخص).
3. **ثبت‌نام عمومی**: تا انتشار بسته می‌ماند؛ باز شدن فقط بعد از فاز ۳ با تست و rate limit.

## فاز ۰ — تثبیت پایه ✅

- [x] تأیید مستقل tip/PR/CI (`2ebd9d8`، ۳ check-run سبز)
- [x] Merge PR #3 → master (`725c8fa`) + push tag `stabilization-baseline`
- [x] بازتولید CI محلی روی baseline جدید: `flutter pub get --enforce-lockfile`, `flutter analyze --no-fatal-infos` (بدون issue), `flutter test` (۳۴۵/۳۴۵ سبز — 2026-11-06)
- [ ] محافظت از `master`: required CI checks + ممنوعیت force-push (اقدام مالک در Settings→Branches یا با gh CLI)

## فاز ۱ — P0 داده و امنیت (هفته ۱-۲)

- [ ] **ممیزی APK واقعی گوشی** (ADB): package ID، versionCode/versionName، SHA-256 گواهی signing و خود APK، تطبیق با commit؛ تست واقعی sign-in، پیام فارسی ۴۲۹، restore fail-closed
- [ ] **Release signing**: ساخت keystore + `android/key.properties`، build signed reproducible، نگهداری/بکاپ آفلاین کلید (P0 هندآف §10.2)
- [ ] **بکاپ مستقل از سرور** (ددلاین سخت **2026-11-30**، قبل از customer data): pull شبانه‌ی رمزگذاری‌شده به مقصد مستقل + `verify_recovery_set.py` + restore drill اپراتور دوم + ثبت RPO/RTO
- [ ] **Deploy بازیابی تراکنشی** (تصمیم ۲ بالا): fresh atomic recovery set، clone rehearsal مجدد، پنجره نگهداری، rollback آماده، acceptance طبق هندآف §10.1؛ بعد از اولین receipt فقط forward-only

## فاز ۲ — عملیات قابل اتکا (هفته ۳-۴)

- [ ] مانیتورینگ external مستقل از VPS: health، 5xx، TLS expiry، backup age/integrity + alert واقعی و runbook
- [ ] انتقال توکن اندروید از SharedPreferences به Keystore-backed storage
- [ ] supply chain: secret/dependency scanning، SBOM، pinned Actions، signed releases
- [x] cloud invariants: CAS/idempotency برای writeهای حساس people/deals/settlements (اسلایس ۱؛ evidence `CLOUD-WRITE-CAS-EVIDENCE-2026-11-23.md`؛ **production deploy 2026-11-23**)
- [x] cloud invariants: coin/currency CAS (اسلایس ۲؛ `CLOUD-WRITE-CAS-CATALOG-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23)
- [x] cloud invariants: allocation replace CAS + audit (اسلایس ۳؛ `ALLOCATION-REPLACE-CAS-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23)
- [x] atomic workspace bootstrap (ZAR-DATA-005؛ `WORKSPACE-BOOTSTRAP-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23)
- [x] cash append CAS (اسلایس ۴؛ `CASH-APPEND-CAS-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23) — §10.5 write CAS کامل؛ gate تبلیغ multi-device تا soak
- [x] consistent snapshot read (ZAR-DATA-006؛ `SNAPSHOT-CONSISTENCY-EVIDENCE-2026-11-23.md`)
- [x] domain upsert invariants + terminal lifecycle lock (ZAR-DATA-003/008 slice؛ `DOMAIN-WRITE-INVARIANTS-EVIDENCE-2026-11-23.md`)
- [x] deep upsert amount/pricing parity (ZAR-DATA-003؛ `DOMAIN-UPSERT-AMOUNT-PRICING-EVIDENCE-2026-11-24.md`)
- [x] restore amount structural share (ZAR-DATA-003؛ `RESTORE-DOMAIN-AMOUNT-SHARE-EVIDENCE-2026-11-24.md`)
- [x] restore deal-pricing structural share + purity-unknown parity (ZAR-DATA-003؛ `RESTORE-DOMAIN-PRICING-SHARE-EVIDENCE-2026-11-24.md`)
- [x] create-time actor stamp (ZAR-DATA-003؛ `CREATE-TIME-ACTOR-STAMP-EVIDENCE-2026-11-24.md`)
- [x] createdAt immutability on upsert updates (ZAR-DATA-003؛ `CREATED-AT-IMMUTABLE-EVIDENCE-2026-11-24.md`)
- [x] terminal field freeze on posted deals/settlements (ZAR-DATA-008؛ `TERMINAL-FIELD-FREEZE-EVIDENCE-2026-11-24.md`) — remaining: period lock + reversal-only correction
- [x] conflict reload UX snackbar (ZAR-DATA-002؛ `CONFLICT-RELOAD-UX-EVIDENCE-2026-11-24.md`)
- [x] workspace epoch remote watch (ZAR-DATA-002؛ `WORKSPACE-EPOCH-REMOTE-WATCH-EVIDENCE-2026-11-24.md`)
- [x] workspace epoch SSE realtime + poll fallback (ZAR-DATA-002؛ `WORKSPACE-EPOCH-SSE-EVIDENCE-2026-11-24.md`)
- [x] Caddy SSE flush for `/api/realtime` (ZAR-DATA-002؛ `CADDY-SSE-FLUSH-EVIDENCE-2026-11-24.md`)
- [x] Device QA APK 20083 built (actor/epoch/SSE؛ `DEVICE-QA-APK-20083-EVIDENCE-2026-11-24.md`) — remaining: adb install + physical soak (`MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`)

## فاز ۳ — آمادگی انتشار (هفته ۵-۶)

- [ ] تکمیل runbooks (release, incident, backup) و اجرای دوباره توسط اپراتور دوم
- [ ] Release Candidate + soak ۷-۱۴ روزه بدون P0/P1
- [x] سیاست ثبت‌نام: بسته تا لانچ (§10.4؛ `SIGNUP-POLICY-CLOSED-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23)
- [ ] تصمیم باز کردن ثبت‌نام + ضد-abuse در لانچ (bootstrap اتمیک آماده است)
- [ ] sign-off: مالک محصول، امنیت، عملیات

## فاز ۴ — حالت «فقط آپدیت» (دائمی)

گردکار تکرارشونده برای هر آپدیت:

1. آپدیت وابستگی/کد در شاخه → CI سبز
2. build signed با build-number صعودی → نصب و تست روی گوشی (ADB)
3. در صورت تغییر server: migration نسخه‌دار + read-only postflight + بکاپ fresh قبل از deploy
4. tag نسخه + به‌روزرسانی `HANDOFF.md`
5. PocketBase فقط patch (بدون minor upgrade در حین workstream فعال)

## قواعد ثابت

- هیچ secret/داده‌ی خصوصی در Git، PR، issue یا doc
- هیچ deploy/mutation روی production بدون fresh backup + rollback + تأیید
- PocketBase listener فقط loopback؛ پورت ۸۰۹۰ هرگز public
- مالی: فقط integer minor units و decimal string؛ بدون float
- دامنه‌ی حسابداری (ledger/tax/P&L) تا sign-off حسابدار متخصص بسته است
