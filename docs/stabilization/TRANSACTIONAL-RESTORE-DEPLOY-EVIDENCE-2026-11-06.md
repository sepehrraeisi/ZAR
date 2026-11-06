# Transactional Restore Deployment — Production Evidence (Phase 1 final gate)

تاریخ پنجره: 2026-11-06 ساعت ~18:25–18:45 UTC — اپراتور: GenCode (zaradmin) — مالک مجوز: صریح (تأیید «بعد از فاز ۱» در 2026-11-06 و «هر کاری صلاح می‌دانی»)
مرجع پلن: `docs/stabilization/TRANSACTIONAL-RESTORE-PLAN.md` — sequence §Production change + rollback forward-only

## گیت‌های پیش از اجرا

1. **fresh atomic recovery set**: `zar-20261106T182450Z` (اجرای دستی zar-backup) — SHA256SUMS `275bc685…50386`، quick_check/integrity_check `ok`
2. **کپی off-site همان snapshot** با `pull-offsite-backups.ps1` — verified + quick_check ok (بدون تغییر سرور)
3. **clone rehearsal run 0005** روی کپی تازه‌ی production: `TRANSACTIONAL_RESTORE_CLONE_REHEARSAL_PASS` — ۶ failpoint، pre-receipt rollback، containmentها، receipt restart/replay، refusalها — evidence: `/root/zar-transactional-restore-clone-20261106-0005` (preflight==postflight state: طول یکسان 6107B)
4. **candidate manifest**: ۱۲ فایل از `master@52ece79` — SHA-256 هر فایل PC↔server بایت‌به‌بایت یکسان؛ `expected_state.json` = `3102b858…` (پین deploy script) و `canary.py` = `8e17b097…`
5.PocketBase نسخه تغییر نکرد (0.40.4، همان باینری)

## اجرا (guarded deploy)

- `guarded_transactional_restore_deploy.sh` با تمام پارامترهای صریح؛ evidence: `/root/zar-transactional-restore-deploy-20261106-0005`
- خروجی: `STATE_GUARD_PASS(before)` → `Applied 1793604800_transactional_restore.js` → `STATE_GUARD_PASS(after)` ×۲ → **`TRANSACTIONAL_RESTORE_DEPLOY_PASS`**

## پذیرش (minute 0)

- سرویس‌ها: zar-server/caddy/zar-backup.timer همه active ✅
- `NRestarts=0` ✅ — health loopback 200 ✅
- listener: فقط `127.0.0.1:8090` ✅ (public 8090 بسته)
- admin route عمومی: `404` ✅
- مهاجرت آخر: `1793604800_transactional_restore.js` ✅
- کالکشن رسید: `zar_restore_receipts` موجود ✅ (رسیدی هنوز صفر است؛ اولین receipt با اولین restore واقعی ساخته می‌شود)
- **قوانین rate: دقیقاً ۱۳** (۱۱ قبلی + `/api/zar/restore/state` + `/api/zar/restore/commit`) ✅
- مسیرهای restore برای بی‌احراز: `401` ✅ (state و commit) — عمومی/loopback یکسان fail-closed
- از این لحظه: `migrate down` ممنوع (بعد از اولین receipt فقط forward-only)

## مشاهده دقیقه ۵/۱۵

- **دقیقه ۵:** active، NRestarts=0، health=200 ✅
- **دقیقه ۱۵:** active، NRestarts=0، health=200، admin public=404 ✅
- هیچ رویداد غیرقابل‌توضیحی مشاهده نشد؛ پنجره با موفقیت بسته شد (اپراتور: GenCode — rollback owner: مالک + GenCode)

## اثر روی client

- کلاینت‌های قدیمی/جدید: restore با رسیدن به مسیر واقعی سرور انجام می‌شود (password re-auth + CAS + idempotency receipt سمت سرور)
- گوشی مالک: release build `18080` (same day) نصب و ورود/بارگذاری ابری موفق

## گردکار نگهداری از این پس

- recovery setها باید `pb_hooks` + manifest را هم شامل شوند (verifier به‌روز است)
- rollback: فقط forward-only؛ down ممنوع پس از هر receipt
