# ZAR+ — Programmer Handoff and Safe Resume Guide

آخرین بازبینی: 2026-11-06 (Asia/Tehran)

مخاطب: برنامه‌نویس، اپراتور سرور، بازبین امنیت و مالک محصول بعدی

وضعیت: **کد و شواهد تثبیت در Draft PR شماره 3 منتشر شده و CI دقیق همان checkpoint سبز است؛ PR هنوز merge نشده و transactional cloud restore هنوز روی production نصب نشده است.**

این فایل نقطه‌ی شروع واحد برای تحویل پروژه است. جزئیات عمیق‌تر در اسناد لینک‌شده آمده‌اند، اما برنامه‌نویس بعدی باید ابتدا این فایل را کامل بخواند.

## 1. خلاصه‌ی اجرایی و مرز مجوز

- مخزن GitHub: `https://github.com/sepehrraeisi/ZAR`
- مخزن در زمان این تحویل **public** است؛ هیچ secret یا داده‌ی خصوصی نباید در آن قرار گیرد.
- شاخه‌ی کار: `codex/stabilization-baseline`
- Draft PR: `https://github.com/sepehrraeisi/ZAR/pull/3`
- شاخه‌ی مقصد: `master`
- baseline قدیمی `master`: `e60d68dda3c1876dc5af99e36c1f455b76fd8a50`
- در بازبینی 2026-11-06، `master` همچنان روی همین commit، `protected=false` و
  repository ruleset list خالی بود؛ baseline commit نیز unsigned است.
- آخرین checkpoint کد/شواهد قبل از انتشار این هندآف:
  `e9ee6e08372d6769b95b78dccff60c4aeb2246f5`
- GitHub Actions run دقیق checkpoint بالا: run `#261`، ID
  `42042024671`، نتیجه `success` برای هر دو job
  `pocketbase-authorization` و `flutter-checks`.
- PR باز، Draft، mergeable و **unmerged** است.
- سبز بودن CI یا merge شدن PR به‌تنهایی مجوز تغییر production نیست.
- هیچ merge، deploy، reboot یا تغییر production در ادامه بدون تصمیم صریح و جداگانه‌ی مالک مجاز نیست.

### چرا GitHub ظاهراً یک هفته است به‌روزرسانی نشده؟

صفحه‌ی پیش‌فرض GitHub شاخه‌ی `master` را نشان می‌دهد. همه‌ی 32 commit تثبیت تا
checkpoint `e9ee6e0` روی شاخه‌ی `codex/stabilization-baseline` و Draft PR شماره 3
منتشر شده‌اند، اما عمداً به `master` merge نشده‌اند. برای مشاهده‌ی کار جدید، PR
شماره 3 یا همان شاخه را باز کنید. برنامه‌نویس بعدی نباید برای «به‌روز نشان دادن»
GitHub، PR را بدون بازبینی و تصمیم مالک merge کند.

برای دیدن tip واقعی هنگام تحویل:

```powershell
git fetch origin
git rev-parse origin/codex/stabilization-baseline
git log -1 --oneline origin/codex/stabilization-baseline
```

## 2. اطلاعات دسترسی سرور — بدون secret

### مسیر دسترسی معتبر فعلی

- Host/IP: `185.126.202.104`
- SSH port: `22`
- alias روی ماشین اپراتور فعلی: `zar-vps`
- SSH user: `zaradmin`
- privilege escalation: `sudo -n`
- کلید عمومی تأییدشده: ED25519، comment برابر `zar-deploy`
- fingerprint کلید عمومی:
  `SHA256:+kDNnHLgms8UaBoXDRuY1O6HcUQT5kTW9WM9QKs/ZdI`
- identity path پیکربندی‌شده روی ماشین اپراتور فعلی: `~/.ssh/zar_vps`
- `IdentitiesOnly yes` فعال است.
- fingerprint کلید میزبان SSH در evidence فعلی ثبت نشده است؛ برای onboarding
  دستگاه جدید باید آن را از کنسول provider گرفت و خارج از خود کانال SSH تطبیق داد.

تنظیم مؤثر SSH سرور در آخرین بازبینی:

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
```

نام کاربری `root` که در شروع پروژه مطرح شده بود دیگر مسیر ورود مستقیم نیست.
ورود root و ورود password-only عمداً غیرفعال و آزمایش شده‌اند. هیچ رمز عبور سرور،
کلید خصوصی، token، signing key یا superuser credential به من داده نشده یا در این
هندآف نگهداری نشده است؛ بنابراین «password قابل تحویل» وجود ندارد.

### تحویل امن دسترسی به برنامه‌نویس جدید

1. برنامه‌نویس جدید روی دستگاه خودش یک کلید ED25519 جدید بسازد و فقط public key
   و fingerprint آن را از یک کانال تأییدشده به مالک بدهد.
2. مالک یا اپراتور فعلی public key جدید را برای `zaradmin` اضافه کند؛ کلید خصوصی
   فعلی نباید کپی یا ارسال شود.
3. برنامه‌نویس جدید host fingerprint را از یک کانال مستقل با مالک تطبیق دهد، یک
   نشست جدید باز کند و `sudo -n true` و `sudo -n whoami` را آزمایش کند.
4. تا قبل از موفقیت نشست دوم، دسترسی قبلی حذف نشود.
5. پس از تأیید، fingerprint، مالک کلید، تاریخ ایجاد و تاریخ ابطال ثبت شود و کلید
   قدیمی در صورت پایان مسئولیت revoke شود.
6. هر credential اپلیکیشن یا PocketBase superuser باید توسط مالک rotate/create
   و از password manager یا کانال رمزگذاری‌شده تحویل شود؛ هرگز در Git، issue، PR،
   ایمیل عادی، chat، shell history یا این فایل قرار نگیرد.

دسترسی GitHub جدا از SSH سرور است. چون repository عمومی است، clone و review به
credential مشترک نیاز ندارد. برای push/review، مالک باید حساب شخصی برنامه‌نویس
جدید را با کمترین permission لازم دعوت کند و 2FA را الزام کند؛ PAT، session یا
recovery code حساب فعلی نباید منتقل شود.

مواردی که علاوه بر password/private key نباید منتقل یا commit شوند: GitHub PAT و
recovery code، DNS/provider/SMTP credential، DKIM و ACME private material، Android
keystore و signing password، recovery key، فایل‌های `.key.dpapi` و archiveهای
rollback قبل از secret scan. bundleهای DPAPI موجود به کاربر/Windows مالک وابسته‌اند
و به‌تنهایی روی دستگاه برنامه‌نویس جدید قابل استفاده نیستند.

ورود عادی پس از onboarding:

```powershell
ssh zar-vps
ssh zar-vps 'sudo -n whoami'
```

خروجی فرمان دوم باید `root` باشد. این فقط آزمون دسترسی است و مجوز mutation نیست.

## 3. موجودی production در آخرین بازبینی

این اطلاعات در 2026-11-06 با بررسی read-only دوباره تأیید شد:

- hostname: `ubuntu`
- OS: Ubuntu 24.04
- kernel: Linux `6.8.0-41-generic`، `x86_64`
- PocketBase: `v0.40.4`
- public URLs:
  - `https://app.titangold.ir`
  - `https://zar.185-126-202-104.sslip.io`
- سرویس اپلیکیشن: `zar-server.service`
- reverse proxy: Caddy
- حساب سرویس: `zarapp:zarapp`، locked و بدون login shell
- PocketBase فقط روی `127.0.0.1:8090` گوش می‌دهد؛ port 8090 نباید public شود.
- دیسک هنگام آخرین capture: حدود 28 GiB کل، 5.6 GiB مصرف و 21 GiB آزاد
  (`22%` مصرف).
- سرور shared است و سرویس‌های دیگری مانند BIND9، Postfix/OpenDKIM و SSH نیز روی
  آن فعال بوده‌اند؛ فایل‌ها یا سرویس‌های خارج از محدوده‌ی ZAR را تغییر ندهید.

### مسیرها و ownership

```text
/opt/zar/server/                         root:root 0755
/opt/zar/server/pocketbase               root:root 0755
/opt/zar/server/pb_migrations/           root:root 0755; files 0644
/opt/zar/server/pb_hooks/                root:root 0755; files 0644
/opt/zar/server/pb_data/                 zarapp:zarapp 0700
/opt/zar/server/pb_data/data.db          zarapp:zarapp 0600
/opt/zar/server/pb_data/auxiliary.db     zarapp:zarapp 0600
/etc/systemd/system/zar-server.service
/etc/systemd/system/zar-server.service.d/10-hardening.conf
/etc/caddy/Caddyfile
/etc/ssh/sshd_config.d/00-zar-hardening.conf
/usr/local/sbin/zar-backup
/etc/systemd/system/zar-backup.service
/etc/systemd/system/zar-backup.timer
/backups/zar-daily/                      root:root 0700
/etc/sudoers.d/90-zaradmin               root:root 0440
```

ExecStart تولید فعلی:

```text
/opt/zar/server/pocketbase serve --http=127.0.0.1:8090
```

unit نسخه‌شده‌ی candidate، مسیرهای data/migrations/hooks را صریح می‌کند و
`--hooksWatch=false` دارد. نصب آن روی production هنوز انجام نشده است.

### وضعیت سرویس و بکاپ

- `zar-server`, `caddy` و `zar-backup.timer` در آخرین بازبینی active بودند.
- timer بکاپ enabled است؛ اجرای روزانه در `03:00 UTC` با random delay محدود.
- آخرین اجرای طبیعی مشاهده‌شده در این تحویل: 2026-11-06 ساعت `03:00:11 UTC`؛
  snapshot `zar-20261106T030011Z` با `SHA256SUMS: OK`، SQLite
  `PRAGMA quick_check: ok` و modeهای `0700/0600` تأیید شد.
- snapshotها اتمیک، دارای SHA-256 و metadata هستند و quick/integrity/schema checks
  را طی می‌کنند.
- retention: 30 روز و هرگز کمتر از 7 snapshot موفق با نام دقیق.
- snapshotهای زمان‌بندی‌شده هنوز روی همان سرورند؛ این disaster recovery مستقل
  نیست.
- یک bundle رمزگذاری‌شده و restore-tested روی کامپیوتر مالک وجود دارد، اما طبق
  تصمیم مالک فقط exception موقت pre-customer است و پیش از customer data، launch
  یا 2026-11-30 باید با placement مستقل جایگزین شود.

بررسی read-only پایه:

```powershell
ssh zar-vps 'sudo -n systemctl is-active zar-server caddy zar-backup.timer'
ssh zar-vps 'curl -fsS http://127.0.0.1:8090/api/health'
ssh zar-vps 'sudo -n systemctl status zar-server --no-pager'
```

در بررسی‌ها secret، environment خصوصی، database row یا credential را چاپ نکنید.

## 4. معماری و مرز محصول

- client اصلی Flutter/Dart و Persian-first/RTL است.
- local state با Drift/SQLite نگهداری می‌شود.
- backend عملیاتی PocketBase است.
- مسیر Firestore در کد وجود دارد ولی production Firebase غیرفعال/opt-in است.
- مبالغ پولی با integer minor units و وزن/طلای دقیق با decimal string مدل شده‌اند؛
  binary floating point برای داده‌ی مالی ممنوع است.
- deal، settlement، physical delivery و cash journal اثرهای جدا دارند.
- cash journal append-only است؛ اصلاح باید با reversal/adjustment قابل ردگیری باشد.
- cloud snapshot/restore باید کاملاً workspace-scoped، atomic، idempotent و دارای
  optimistic concurrency باشد.

نقشه‌ی مسیرهای کد:

```text
lib/domain/          مدل‌ها و invariantهای دامنه
lib/application/     orchestration و backup manager
lib/data/local/      Drift/SQLite repository
lib/data/pocketbase/ PocketBase client/repository و cloud sync/restore
lib/data/firestore/  مسیر dormant/opt-in Firestore
lib/features/        UI و feature wiring شامل auth و backup
test/                Flutter/unit/widget/regression tests
server/pb_migrations source-of-truth migration lineage
server/pb_hooks/     transactional restore hooks (فعلاً candidate)
server/deploy/       templateهای Caddy/systemd
server/scripts/      guarded deploy/rollback/containment و canaryها
server/tools/        backup و recovery verifier
server/tests/        real PocketBase و guard/state suites
```

جریان production:

```text
Flutter/Android
  → HTTPS
  → Caddy
  → 127.0.0.1:8090 PocketBase
  → pb_data/data.db + pb_data/auxiliary.db
```

داده‌ی device-local از Drift می‌آید؛ داده‌ی cloud از PocketBase و workspace scope
می‌آید. restore کامل DB از runbook/verified recovery set انجام می‌شود. cloud
snapshot replace معمولی برای cash در production فعلی عمداً fail-closed است؛ مسیر
transactional جدید فقط candidate است.

مهم: مستندات فعلی محصول ZAR+ را «ابزار عملیاتی طلا و ارز» تعریف می‌کنند، نه یک
general ledger کامل. P&L، tax، chart of accounts، period close و financial
statements هنوز دامنه‌ی مصوب نیستند. امنیت، recovery و integrity باید ادامه
یابد، اما افزودن قابلیت حسابداری جدید تا تصمیم رسمی مالک و تأیید حسابدار متخصص
ممنوع است.

## 5. کاری که انجام شده است

در checkpoint `e9ee6e0` نسبت به `master` اولیه، 32 commit، 75 فایل تغییرکرده،
17,540 خط اضافه و 465 خط حذف شده است. فهرست زیر خلاصه‌ی workstreamهاست؛ تاریخچه‌ی
کامل در `HANDOFF.md` ثبت شده است.

### ماتریس وضعیت workstreamها

- Workspace deletion lock — در Git: بله؛ local/CI: پاس؛ production: نصب و
  تأییدشده؛ کار باز: ندارد جز regression دائمی.
- Cash append-only lock/reversal — در Git: بله؛ real PocketBase tests: پاس؛
  production: نصب و تأییدشده؛ کار باز: audit/reversal model گسترده‌تر.
- Workspace-scoped cloud reads — در Git: بله؛ regression tests: پاس؛ production
  client artifact: APK نصب‌شده هنوز تطبیق داده نشده است.
- SSH/service/admin containment — در Git و production: نصب و تأییدشده؛ کار باز:
  onboarding کلید مستقل و monitoring.
- Atomic backup/restore verifier — در Git و production: نصب/پاس؛ کار باز: مقصد
  مستقل، second-operator drill و RPO/RTO.
- Rate limiting — در Git/clone/CI: پاس؛ production: 11 rule نصب و مشاهده‌شده؛
  کار باز: تأیید Persian 429 در APK واقعی.
- Transactional cloud restore — در Git/CI/fresh clone: پاس؛ production: **نصب
  نشده**؛ کار باز: تصمیم مالک و change window جداگانه.
- Android release identity/signing — در Git راهنما وجود دارد؛ evidence artifact
  نصب‌شده: موجود نیست؛ کار باز: P0.
- Full accounting/GL — پیاده‌سازی یا دامنه‌ی مصوب ندارد؛ کار باز: تصمیم مالک و
  accountant sign-off، نه توسعه‌ی حدسی.

منظور از reviewهای مستقل در این workstream، بازبینی‌های جداگانه‌ی فنی/agent در
همین فرآیند است؛ هیچ attestation یا ممیزی حرفه‌ای شخص ثالث ارائه نشده است.

### Baseline و characterization

- repository، CI، migration lineage، deployment docs و server به‌صورت read-only
  inventory شدند.
- نسخه‌ها، checksumها، configها، ruleها، schema/countها و service boundaries ثبت
  شدند.
- Flutter baseline، analyzer و coverage اجرا شد.
- دو migration تولید-only مربوط به email template از production بازیابی و
  byte-for-byte با lineage محلی آشتی داده شدند.

### جلوگیری از حذف و خرابی داده

- حذف ناشناس workspace در PocketBase بازتولید و با migration نسخه‌شده بسته شد.
- update/delete cash journal برای کاربر عادی بسته و reversal path حفظ شد.
- همه‌ی queryهای cloud snapshot/load/discovery به workspace انتخاب‌شده محدود شد.
- client restore برای snapshot دارای cash یا وضعیت cash موجود fail-closed شد و
  پیام کنترل‌شده‌ی فارسی دارد.
- regression tests برای authorization، isolation، persistence failure، restore
  guard و retry اضافه شد.

### Recovery و backup

- verifier غیرمخرب `server/tools/verify_recovery_set.py` اضافه شد.
- restore واقعی backup مشتق از production در محیط ایزوله با zero unexplained
  reconciliation difference پاس شد.
- fallback bundle محلی رمزگذاری‌شده ساخته، decrypt، hash-verify و restore شد.
- cron ناامن با backup اتمیک systemd، checksums، integrity/schema verification،
  retention محدود و sandbox بدون network جایگزین شد.
- اجرای دستی و اولین/چند اجرای طبیعی timer تأیید شد.

### SSH، service و admin containment

- دسترسی مستقیم root/password به SSH با `zaradmin` key-only و sudo غیرتعاملی
  جایگزین شد.
- PocketBase از root به `zarapp` locked منتقل، filesystem محدود و data mode به
  `0700/0600` تغییر کرد.
- listener به loopback محدود شد و امتیاز exposure سرویس از `9.6 UNSAFE` به
  `2.8 OK` رسید.
- مسیرهای public dashboard، superuser، schema، logs، backup، cron، SQL و
  impersonation در Caddy با `404` محصور شدند؛ دسترسی admin فقط با SSH tunnel است.

### Rate limiting

- policy پیش‌فرض ناسازگار با batch رد شد.
- policy اختصاصی 11-rule برای ZAR طراحی و روی clone با batch/concurrency/reset و
  Real-IP آزمایش شد.
- guarded deploy و rollback بدون default target نوشته و failpoint-tested شد.
- migration rate limit در 2026-11-01 روی production نصب شد؛ checks در دقیقه‌های
  0/5/15، integrity، counts، logs و restart همگی پاس شدند.
- UX فارسی 429 در source وجود دارد، ولی وجود آن در APK نصب‌شده‌ی گوشی هنوز اثبات
  نشده است.

### Transactional cloud restore candidate

- یک server-side compare-and-swap transaction برای جایگزینی اتمیک هر هفت
  collection دامنه، شامل cash، پیاده‌سازی شد.
- password re-authentication، single-member authorization، membership
  immutability، bounded validation و private idempotency receipt اضافه شد.
- state hash، revision/ambiguity handling و replay receipt پیاده‌سازی شد.
- guarded deploy، rollback پیش از receipt و forward-only containment پس از receipt
  نوشته شد.
- دو دور security review و چند closure audit مستقل مشکلات trust path، symlink،
  hardlink، fail-open restart، production-port targeting، evidence race و
  receipt/baseline recovery را پیدا و بسته‌اند.
- rehearsal نهایی `0004` روی clone تازه‌ی production، unit موقت و port loopback
  جداگانه تمام failpointها، commit/restart/replay و recoveryها را پاس کرد.

## 6. دقیقاً چه چیزی روی production نصب است و چه چیزی نیست

### نصب و تأییدشده روی production

- `1793260800_lock_workspace_deletion.js`
- `1793347200_lock_cash_entry_deletion.js`
- `1793394000_trust_caddy_client_ip.js`
- `1793437200_enable_rate_limits.js`
- Caddy admin-route containment
- hardened `zar-server.service` با user `zarapp` و loopback listener
- verified `zar-backup.service` و `zar-backup.timer`
- policy rate-limit دقیقاً 11 rule فعال

### فقط candidate در شاخه و هنوز نصب‌نشده

- `1793604800_transactional_restore.js`
- `server/pb_hooks/zar_restore.js`
- `server/pb_hooks/zar_restore_routes.pb.js`
- `server/deploy/zar-server-transactional-restore.conf`
- routeهای transactional restore

آخرین postflight production موارد زیر را اثبات کرد:

- restore route برابر `404`
- candidate migration و هر دو hook غایب
- unit تولید بدون hook argument جدید
- rate policy دقیقاً 11 rule
- `zar-server` و Caddy سالم
- hash وضعیت sanitized قبل و بعد از clone drill یکسان

در read-only postflight روز 2026-11-06 نیز `zar-server`, Caddy و backup timer
active، `NRestarts=0`، health loopback برابر HTTP `200`، listener فقط
`127.0.0.1:8090` و سه فایل candidate همچنان absent بودند.

بنابراین rehearsal یا سبز بودن CI را با production deployment اشتباه نگیرید.

## 7. شواهد نهایی و نتایج آزمون

### GitHub/CI

- exact code/evidence checkpoint:
  `e9ee6e08372d6769b95b78dccff60c4aeb2246f5`
- Actions run: `https://github.com/sepehrraeisi/ZAR/actions/runs/42042024671`
- run number: `261`
- نتیجه: success
- jobs: `pocketbase-authorization`, `flutter-checks`

### تست‌های آخرین checkpoint

- toolchain ثبت‌شده: Flutter `3.47.2` و PocketBase `0.40.4`; ثبت کامل Android/JDK
  toolchain، SBOM و reproducible signed APK هنوز باز است.
- Flutter: 345 test، صفر failure
- `flutter analyze --no-fatal-infos`: بدون finding
- debug web build: pass
- deterministic state/guard/canary: 24 test؛ 22 pass و 2 skip مورد انتظار
- real PocketBase authorization suite: pass
- migration-lineage suite: pass
- transactional-restore suite: pass
- real commit → systemd restart → receipt replay: pass
- shell syntax، Python compilation و Git whitespace: pass

### clone rehearsal نهایی

- run: `0004`
- transient unit: `zar-restore-clone-20261105-0004.service`
- listener: `127.0.0.1:18093`
- production port `8090` عمداً reject شد.
- transition دقیق rate rules: `11 → 13 → 11`
- production sanitized pre/post SHA-256:
  `de933d1a36a3b18816f6b26a2f019ff3739acc0854b57c293b39cbcdc21b1ed3`
- expected-state manifest SHA-256:
  `3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3`
- canary SHA-256:
  `8e17b0973846da01c158f2960e9709594a1b3742fb39cf27b29a458d75c0f697`
- sanitized archive SHA-256:
  `a23327950bef4b5b997233c6b58e7d02d88569475fad632bf2dd42322a85e927`
- archive: 365 entry، بدون symlink، unsafe path، database یا private state؛ 164
  JSON entry نیز برای نبود private canary material بررسی شد.

### محل شواهد

روی سرور:

```text
/root/zar-transactional-restore-clone-20261105-0004
/root/zar-restore-candidate-20261105-0004
/root/zar-rate-limit-production-20261101T195200Z
/root/zar-admin-access-20261031T084900Z
/root/zar-backup-automation-20261030T200203Z
```

روی ماشین مالک/اپراتور:

```text
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\transactional-restore-clone-20261105-0004\zar-transactional-restore-clone-20261105-0004.tar.gz
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-production-20261101\zar-rate-limit-production-evidence-20261101.tar
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\rate-limit-canary-20261031\zar-rate-limit-evidence-complete-v6-20261031.tar
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\admin-access-20261031T084900Z\zar-admin-access-20261031T084900Z-evidence.tar
C:\Users\simin\Documents\Codex\2026-10-28\fh-x20\work\recovery-evidence-20261030\restore-report.json
C:\Users\simin\Documents\Codex\ZAR-Recovery
```

این archiveها sanitized یا محدودشده‌اند، ولی قبل از هر انتقال دوباره باید بررسی
شوند. این مسیرهای Windows و archiveهای `/root` داخل GitHub نیستند و روی سیستم
برنامه‌نویس جدید خودکار در دسترس نخواهند بود؛ مالک باید availability و روش تحویل
هرکدام را جداگانه ثبت کند. evidenceهای Git باید دائمی بمانند؛ archiveهای خارج Git
حداقل تا پذیرش تحویل، تصمیم release/deploy و پایان نیاز rollback حفظ شوند. database،
credential یا private state نباید به Git اضافه شود. DPAPI/recovery material فقط
از مسیر امن و همراه با آزمون decrypt/restore روی مقصد قابل تحویل است.

## 8. فهرست اسناد و کاربرد هرکدام

نقطه‌ی ورود:

- `docs/stabilization/PROGRAMMER-HANDOFF.md` — همین فایل؛ دسترسی، وضعیت، شواهد،
  مسیر شروع و roadmap.
- `docs/stabilization/HANDOFF.md` — action log زمان‌دار و تاریخچه‌ی کامل کار.
- `docs/stabilization/FINDINGS.md` — register ریسک‌ها، شدت، وضعیت و کارهای باز.
- `docs/stabilization/BASELINE.md` — baseline نسخه‌ها، سرور، schema و checksums.

Recovery:

- `docs/stabilization/RESTORE-RUNBOOK.md` — restore/reconciliation عملیاتی.
- `docs/stabilization/TEMPORARY-RECOVERY-EXCEPTION.md` — استثنای موقت بکاپ
  pre-customer و deadline آن.
- `docs/stabilization/BACKUP-AUTOMATION-PLAN.md` — طراحی backup timer.
- `docs/stabilization/BACKUP-AUTOMATION-EVIDENCE-2026-10-30.md` — شواهد نصب و
  restore backup.

Production containment:

- `docs/stabilization/PRODUCTION-CONTAINMENT-CHANGE-PLAN.md`
- `docs/stabilization/PRODUCTION-CONTAINMENT-EVIDENCE-2026-10-30.md`
- `docs/stabilization/SSH-HARDENING-PLAN.md`
- `docs/stabilization/SSH-HARDENING-EVIDENCE-2026-10-30.md`
- `docs/stabilization/POCKETBASE-SERVICE-HARDENING-PLAN.md`
- `docs/stabilization/POCKETBASE-SERVICE-HARDENING-EVIDENCE-2026-10-30.md`
- `docs/stabilization/ADMIN-ACCESS-CONTAINMENT-PLAN.md`
- `docs/stabilization/ADMIN-ACCESS-CONTAINMENT-EVIDENCE-2026-10-31.md`

Rate limiting:

- `docs/stabilization/RATE-LIMITING-PLAN.md`
- `docs/stabilization/RATE-LIMITING-EVIDENCE-2026-10-31.md`
- `docs/stabilization/RATE-LIMITING-PRODUCTION-EVIDENCE-2026-11-01.md`

Transactional restore candidate:

- `docs/stabilization/TRANSACTIONAL-RESTORE-PLAN.md` — security contract، deploy،
  containment و rollback.
- `docs/stabilization/TRANSACTIONAL-RESTORE-LOCAL-EVIDENCE-2026-11-03.md`
- `docs/stabilization/TRANSACTIONAL-RESTORE-CLONE-EVIDENCE-2026-11-05.md` — شواهد
  پذیرفته‌شده‌ی final clone.
- `server/README.md` — راهنمای فارسی استقرار امن و server source of truth.

## 9. روش شروع برنامه‌نویس بعدی

### مرحله 1 — دریافت کد درست

```powershell
git clone https://github.com/sepehrraeisi/ZAR.git
Set-Location ZAR
git fetch origin
git switch --track origin/codex/stabilization-baseline
git status --short --branch
git log -5 --oneline
```

پیش از هر کار، PR شماره 3، این فایل، `HANDOFF.md`، `FINDINGS.md` و
`TRANSACTIONAL-RESTORE-PLAN.md` کامل خوانده شوند. اگر branch tip با PR head فرق
داشت، کار را متوقف و علت را ثبت کنید؛ روی commit حدسی deploy نکنید.

### مرحله 2 — بازتولید CI محلی

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
flutter test
flutter build web --debug
```

روی Linux/CI با PocketBase 0.40.4 و hash پین‌شده، همان دستورات
`.github/workflows/phase_a2_ci.yml` اجرا شوند:

```bash
bash -n \
  server/scripts/guarded_transactional_restore_deploy.sh \
  server/scripts/guarded_transactional_restore_rollback.sh \
  server/scripts/guarded_transactional_restore_contain.sh \
  server/scripts/test_guarded_transactional_restore_clone.sh

python3 -m unittest -v \
  server.tests.transactional_restore_state_test \
  server.tests.transactional_restore_state_guard_test \
  server.tests.transactional_restore_expected_state_test \
  server.tests.transactional_restore_canary_test

python3 server/tests/pocketbase_authz_test.py --pocketbase "$PWD/pocketbase"
python3 server/tests/pocketbase_migration_lineage_test.py --pocketbase "$PWD/pocketbase"
python3 server/tests/pocketbase_transactional_restore_test.py --pocketbase "$PWD/pocketbase"
```

PocketBase binary را فقط از release رسمی با SHA-256 پین‌شده‌ی CI بگیرید. نسخه را
در همین workstream ارتقا ندهید.

### مرحله 3 — read-only production confirmation

بعد از تحویل امن کلید جدید:

1. login و `sudo -n` را بدون تغییر state اثبات کنید.
2. active بودن `zar-server`, `caddy`, `zar-backup.timer` را بررسی کنید.
3. health loopback و هر دو URL عمومی را بررسی کنید.
4. listener را فقط loopback و external 8090 را بسته تأیید کنید.
5. candidate route/file/history را absent و rate rule count را 11 تأیید کنید.
6. آخرین backup age و گزارش verify را بدون چاپ داده‌ی خصوصی بررسی کنید.
7. نتیجه و UTC timestamp را به هندآف اضافه کنید.

این مرحله discovery جدید یا مجوز تغییر production نیست.

## 10. نقشه‌ی راه پیشنهادی

### P0 — قبل از اعلام پایداری، customer data یا release

#### 10.1 تصمیم درباره‌ی transactional cloud restore

مالک باید یکی را صریحاً انتخاب کند:

1. cloud cash restore فعلاً fail-closed بماند؛ یا
2. یک deployment جداگانه با maintenance window، operator و rollback owner مشخص
   تأیید شود.

اگر deployment انتخاب شد، قبل از اجرا باید fresh atomic recovery set، hash/schema/
counts/integrity هر دو SQLite، clone rehearsal همان snapshot، exact commit و
expected manifest دوباره تأیید شوند. acceptance باید migration history، `11→13`
rules، receipt metadata hash، domain counts/content hashes، health، admin denial،
listener، `NRestarts=0`، logs محدود و مشاهده‌ی دقیقه‌های 0/5/15 را با zero
unexplained difference ثبت کند.

بعد از ایجاد حتی یک receipt یا هر ambiguous commit outcome، `migrate down` ممنوع
است. recovery فقط forward-only، quarantine route و حفظ migration/receipt است.

#### 10.2 بررسی APK واقعی گوشی

ADB در این ماشین در مسیر زیر موجود بود، ولی هنگام بازبینی هیچ دستگاهی connected/
authorized نبود:

```text
C:\Users\simin\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

با USB debugging و تأیید مالک، موارد زیر ثبت شوند:

- package ID، `versionCode`، `versionName`
- SHA-256 گواهی signing و hash خود APK
- تطبیق artifact با source commit/release
- startup و sign-in واقعی
- Persian 429 UX
- cash restore controlled-recovery و unknown/ambiguous outcome UX
- clean reproducible signed release build و custody/backup کلید signing

تا آن زمان source tests نباید به‌عنوان اثبات نسخه‌ی نصب‌شده معرفی شوند.

#### 10.3 حذف استثنای بکاپ same-host

قبل از customer data، launch یا 2026-11-30:

- مقصد مستقل و رمزگذاری‌شده انتخاب شود.
- RPO، RTO، maximum downtime، retention و custodian کلید تصویب شوند.
- replication زمان‌بندی‌شده و alert برای backup age/integrity اضافه شود.
- یک second operator restore کامل را اجرا کند.
- checksum، integrity، health، reconciliation و زمان واقعی restore ثبت شود.

#### 10.4 تعیین سیاست public signup

مالک باید مشخص کند signup بسته است یا عمداً عمومی. policy باید versioned،
server-enforced و دارای real PocketBase allow/deny tests باشد. اگر عمومی ماند،
abuse/rate limit، atomic workspace bootstrap و duplicate/orphan tests الزامی است.

#### 10.5 بستن مرزهای یکپارچگی cloud

- optimistic concurrency/CAS و server revision برای همه‌ی writeهای حساس
- idempotency key و conflict قابل‌بازیابی برای stale device
- server-side invariant boundary و parity tests بین local/cloud
- حذف hard-delete از باقی history/financial collections و طراحی reversal/
  tombstone/audit با actor، server time، reason، request ID و before/after linkage
- atomic/idempotent workspace bootstrap بدون orphan/duplicate در retry یا شروع هم‌زمان

اگر هرکدام آماده نیست، قابلیت cloud/multi-device مرتبط باید صریحاً feature-gated
شود.

### P1 — منبع حقیقت و عملیات قابل اتکا

- external monitoring مستقل از همان VPS برای health، 5xx، latency، disk، TLS
  expiry، backup age/integrity، auth anomaly و restart loop
- alert delivery واقعی، owner/on-call، threshold، escalation و runbook آزمایش‌شده
- انتقال token اندروید از `SharedPreferences` به Keystore-backed storage
- Android backup/data-extraction policy و تصمیم مستند درباره‌ی local DB encryption
- signing-key custody و recovery drill
- branch protection روی `master`، required checks/reviews، pinned toolchain/actions
- secret/dependency/SAST scans، SBOM، provenance، checksums و signed releases
- atomic allocation replacement، consistent snapshot revision، lifecycle matrix،
  period lock و reversal-only correction برای posted history
- تصمیم legal/business برای receipt retention و purge فقط به‌صورت forward-only

### P2 — تکمیل stabilization و آمادگی انتشار

- تکمیل architecture، data dictionary، API/auth matrix، test strategy، release،
  security، incident و backup/restore runbooks
- اجرای runbookها توسط second operator
- افزایش coverage در PocketBase auth، cloud shell، backup UI و repository
- اندازه‌گیری practical restore limits، transaction duration، retry budget و failure behavior
- enforce HTTPS در release و timeout/cancellation صریح
- بازبینی currency scale defaults و تمام invariantهای مالی با golden examples
- release candidate pilot/soak به مدت 7 تا 14 روز بدون P0/P1
- sign-off مالک محصول، accounting/domain owner، security reviewer و operations owner

### ثبت کوتاه ریسک‌های باقی‌مانده

- بکاپ مستقل — owner: مالک/operations؛ deadline: قبل از customer/launch یا
  2026-11-30؛ پذیرش: encrypted off-host copy + second-operator restore + RPO/RTO.
- APK و signing — owner: Android/release owner؛ deadline: قبل از هر release؛
  پذیرش: package/version/cert/APK hash، source mapping و signed reproducible build.
- Public signup — owner: product + security؛ deadline: قبل از customer؛ پذیرش:
  تصمیم versioned و real allow/deny/abuse/bootstrap tests.
- Monitoring — owner: operations؛ deadline: قبل از production claim/launch؛
  پذیرش: external probes، alert delivery، escalation و simulated-failure evidence.
- Transactional restore deployment — owner: product + operations + security؛
  deadline: فقط پس از تصمیم قابلیت؛ پذیرش: fresh recovery set و کامل‌شدن gate 10.1.
- Cloud invariants/concurrency/audit — owner: backend/domain؛ deadline: پیش از
  تبلیغ multi-device/cloud reliability؛ پذیرش: server-enforced CAS/invariants،
  reversal/audit و concurrent-client tests.
- Supply chain — owner: repository/release؛ deadline: پیش از release candidate؛
  پذیرش: protected `master`، required reviews/checks، SHA-pinned Actions، scans،
  SBOM، provenance و signed artifacts.

### Gate تصمیم دامنه‌ی حسابداری

پیش از هر ledger/tax/P&L/statement feature، یک domain brief رسمی باید مشخص کند
محصول operational workflow باقی می‌ماند یا general ledger واقعی می‌شود. jurisdiction،
tax/legal/retention، posting lifecycle، chart of accounts، period lock، reversal
model، stable invariant IDs، golden examples و automated tests باید با حسابدار
متخصص تصویب شوند.

## 11. کارهای ممنوع یا فقط با تصمیم صریح مالک

- merge کردن Draft PR شماره 3 فقط برای تازه‌کردن تاریخ `master`
- deploy، reboot یا هر mutation روی production بدون workstream، fresh recovery
  evidence، rollback/recovery path و approval جداگانه
- قراردادن password، token، private/signing key، database، personal data یا secret
  config در Git، PR، issue یا هندآف
- کپی کردن کلید خصوصی اپراتور فعلی برای برنامه‌نویس بعدی
- direct edit روی live SQLite یا repair دستی rowهای دامنه
- destructive restore/canary روی production
- اتصال client یا admin عمومی به IP:8090
- دور زدن guarded scripts یا استفاده از target/default حدسی
- ارتقای PocketBase در workstream transactional restore
- کپی hook روی سرویس زنده یا فعال‌کردن hot reload
- حذف receipt یا migration down پس از receipt/ambiguous outcome
- launch یا ورود customer data بعد از deadline با backup صرفاً same-host
- افزودن ledger، tax، P&L یا statement پیش از scope/accountant sign-off
- فرض اینکه CI سبز، clone rehearsal یا merge به معنای مجوز deployment است

## 12. چک‌لیست پذیرش تحویل توسط برنامه‌نویس بعدی

- [ ] این فایل و تمام اسناد بخش 8 کامل خوانده شد.
- [ ] branch/PR/head و نتیجه‌ی CI مستقل از متن این فایل تأیید شد.
- [ ] local Flutter و server suites روی exact head بازتولید شد.
- [ ] کلید SSH جدید با fingerprint ثبت‌شده و بدون انتقال private key تحویل شد.
- [ ] login دوم و `sudo -n` پاس شد و host fingerprint out-of-band بررسی شد.
- [ ] production فقط read-only بررسی و عدم نصب restore candidate تأیید شد.
- [ ] backup age، same-host exception و deadline به‌طور روشن پذیرفته شد.
- [ ] مالک درباره‌ی merge، restore deployment، signup و accounting scope تصمیم‌های
      جداگانه می‌گیرد؛ هیچ‌کدام از متن این هندآف استنباط نمی‌شوند.
- [ ] هر تغییر بعدی با commit، test evidence، UTC timestamp، rollback/recovery و
      به‌روزرسانی `HANDOFF.md` ثبت می‌شود.

اگر در هر مرحله واقعیت production با این سند فرق داشت، ابتدا تغییر را متوقف،
evidence را حفظ و اختلاف را در `FINDINGS.md` و `HANDOFF.md` ثبت کنید؛ تلاش برای
«هماهنگ‌کردن سریع» production با Git بدون تحلیل اختلاف مجاز نیست.
