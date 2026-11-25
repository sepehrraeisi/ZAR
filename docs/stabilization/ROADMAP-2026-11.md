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
- [x] محافظت از `master`: required checks `flutter-checks` / `pocketbase-authorization` / `secrets-scan` / `dependency-sbom`؛ `allow_force_pushes=false`؛ `enforce_admins=true` (تأیید 2026-11-25 via GitHub API)

## فاز ۱ — P0 داده و امنیت (هفته ۱-۲)

- [x] **ممیزی APK واقعی گوشی** (ADB): versionCode **20083** روی Samsung؛ cert `d19ad112…2667`؛ APK SHA `117e117a…d337` (`APK-AUDIT-20083-EVIDENCE-2026-11-25.md`؛ prior `DEVICE-QA-APK-20083-EVIDENCE-2026-11-24.md`)
- [x] **Release signing**: keystore + `android/key.properties` (git-ignored)؛ evidence `RELEASE-SIGNING-EVIDENCE-2026-11-06.md`
- [x] **بکاپ مستقل از سرور**: `pull-offsite-backups.ps1` → `Documents\ZAR-OffsiteBackups` + SHA verify + quick_check (ongoing؛ deadline ops drill remains for second operator)
- [x] **Deploy بازیابی تراکنشی**: production + canary + forward-only lineage (`TRANSACTIONAL-RESTORE` evidence / HANDOFF §0)

## فاز ۲ — عملیات قابل اتکا (هفته ۳-۴)

- [x] مانیتورینگ: on-VPS `zar-health-check.timer` + owner-PC `zar_external_probe.ps1` (`MONITORING-EVIDENCE-2026-11-06.md`) — TLS/backup-age deep probes still optional hardening
- [x] انتقال توکن اندروید به Keystore-backed storage (`ZarSecureTokenStore` / `flutter_secure_storage`)
- [x] Android backup/data-extraction deny (`allowBackup=false` + XML rules؛ `ANDROID-BACKUP-DENY-EVIDENCE-2026-11-25.md`) — مانده: local DB encryption
- [x] enforce HTTPS در release + timeout صریح REST (`RELEASE-HTTPS-CLIENT-TIMEOUT-EVIDENCE-2026-11-25.md`)
- [x] supply chain: secret/dependency scanning، SBOM، pinned Actions (`supply_chain.yml` / GitGuardian)
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
- [x] drop transitional `local-user` create allow after APK 20083 (ZAR-DATA-003؛ `DROP-LOCAL-USER-ACTOR-EVIDENCE-2026-11-24.md`)
- [x] createdAt immutability on upsert updates (ZAR-DATA-003؛ `CREATED-AT-IMMUTABLE-EVIDENCE-2026-11-24.md`)
- [x] terminal field freeze on posted deals/settlements (ZAR-DATA-008؛ `TERMINAL-FIELD-FREEZE-EVIDENCE-2026-11-24.md`) — remaining: period lock + reversal-only correction
- [x] conflict reload UX snackbar (ZAR-DATA-002؛ `CONFLICT-RELOAD-UX-EVIDENCE-2026-11-24.md`)
- [x] workspace epoch remote watch (ZAR-DATA-002؛ `WORKSPACE-EPOCH-REMOTE-WATCH-EVIDENCE-2026-11-24.md`)
- [x] workspace epoch SSE realtime + poll fallback (ZAR-DATA-002؛ `WORKSPACE-EPOCH-SSE-EVIDENCE-2026-11-24.md`)
- [x] Caddy SSE flush for `/api/realtime` (ZAR-DATA-002؛ `CADDY-SSE-FLUSH-EVIDENCE-2026-11-24.md`)
- [x] Device QA APK 20083 built + installed on Samsung (actor/epoch/SSE؛ `DEVICE-QA-APK-20083-EVIDENCE-2026-11-24.md`؛ audit `APK-AUDIT-20083-EVIDENCE-2026-11-25.md`)
- [x] Device QA APK 20084 built + installed (backup deny + release HTTPS/timeout؛ `DEVICE-QA-APK-20084-EVIDENCE-2026-11-25.md`)
- [x] multi-device CAS soak + cross-session epoch/snapshot parity (`MULTI-DEVICE-CAS-SOAK-EVIDENCE-2026-11-23.md`) — remaining: physical soak (`MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`)

## فاز ۳ — آمادگی انتشار (هفته ۵-۶)

- [ ] تکمیل runbooks (release, incident, backup) و اجرای دوباره توسط اپراتور دوم — checklist در `RESTORE-RUNBOOK.md` + `RELEASE-RUNBOOK.md` §۷ + `INCIDENT-RUNBOOK.md`؛ مانده: اجرای واقعی اپراتور دوم + تصمیم ADR رمزنگاری DB
- [ ] Release Candidate + soak ۷-۱۴ روزه بدون P0/P1
- [x] سیاست ثبت‌نام: بسته تا لانچ (§10.4؛ `SIGNUP-POLICY-CLOSED-EVIDENCE-2026-11-23.md`؛ prod 2026-11-23)
- [x] ضد-abuse/rate-limit evidence برای لانچ (`SIGNUP-LAUNCH-ABUSE-EVIDENCE-2026-11-25.md`؛ suite `pocketbase_signup_launch_abuse_test.py`) — مانده: تصمیم مالک + migration رو به جلو برای reopen
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
