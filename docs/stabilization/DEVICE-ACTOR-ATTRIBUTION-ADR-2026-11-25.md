# ADR — Device attribution inside a shared workspace

تاریخ: 2026-11-25  
وضعیت: **Proposed** (نیاز به تصمیم مالک قبل از migration/UI)  
محرک: soak فیزیکی دو دستگاه روی `shahab@zarplus.cloud` / گالری طلای مهر —
چند دستگاه با یک حساب؛ رزومه/تاریخچه امروز فقط `createdBy = userId` را
می‌بیند، نه «کدام گوشی».

## Context

- Workspace چندنفره/چنددستگاه است؛ یک مالک ممکن است Samsung + moto e13 + …
  را با **همان** ایمیل باز کند.
- Create-time actor stamp فعلی (`CREATE-TIME-ACTOR-STAMP-EVIDENCE-2026-11-24.md`)
  فقط PocketBase **user id** را روی `createdBy` / `completedBy` می‌زند.
- بنابراین در رزومه، هر دو گوشی یک بازیگر به نظر می‌رسند؛ برای حسابرسی
  عملیاتی («موتورولا این تعهد را زد / سامسونگ یادداشت را عوض کرد») کافی نیست.

## Decision drivers

1. تشخیص دستگاه بدون اجبار ساختن user جدا برای هر گوشی.
2. عدم افشای شناسه‌های سخت‌افزاری خام در بکاپ/خروجی مشتری.
3. سازگاری با CAS/epoch موجود؛ بدون شکستن APKهای فعلی تا rollout.

## Options

| Option | Idea | Pros | Cons |
|--------|------|------|------|
| A | هر دستگاه = user جدا (invite) | تفکیک قوی | UX سنگین؛ signup بسته؛ برای مالک تنها نامناسب |
| B | `deviceLabel` اختیاری روی هر write (`createdFromDevice` / `updatedFromDevice`) | همان حساب؛ برچسب فارسی در UI | نیاز migration + سیاست نام‌گذاری |
| C | فقط لاگ سرور/SSE بدون فیلد دامنه | سریع | در بکاپ/رزومهٔ مشتری نمی‌آید |

## Recommendation

**Option B (preferred):**

- کلاینت یک `installationId` پایدار (Keystore/secure storage) +
  `deviceLabel` قابل ویرایش کاربر (پیش‌فرض: مدل گوشی، مثلاً `moto e13` /
  `SM-N986U`) نگه می‌دارد.
- روی create: `createdBy` همان user id می‌ماند؛ فیلد جدید
  `createdFromDevice: { installationId, label }` در domain JSON.
- روی update موفق: `updatedFromDevice` + `updatedAt` (و در صورت نیاز
  `updatedBy` = user id برای آیندهٔ multi-member).
- UI رزومه/جزئیات سند: یک خط «از دستگاه: moto e13» زیر یادداشت/متا.
- بکاپ V8+ این فیلدها را حمل می‌کند؛ restore ساختاری validate می‌کند.

## Non-goals (این ADR)

- جایگزینی membership چندکاربره (آن مسیر جداست).
- Fingerprint سخت‌افزاری در UI مشتری.
- تغییر سیاست signup.

## Consequences

- Migration رو به جلو زیر lineage top `1793604800` + evidence جدا.
- تا deploy، soak فیزیکی فقط با مشاهدهٔ دستی/زمان ثبت قابل تفکیک است.
- Conflict CAS همچنان بر `revision` است؛ برچسب دستگاه جایگزین CAS نمی‌شود.

## Open questions for owner

1. برچسب پیش‌فرض: مدل خام اندروید یا نام آزاد («ویترین» / «انبار»)?
2. آیا `installationId` در بکاپ JSON مشتری بیاید یا فقط hash کوتاه؟
3. اولویت نسبت به period-lock / signup reopen؟

## Recommended defaults (engineering, 2026-11-27)

If the owner wants a one-shot «approve defaults» rather than debating each
question, use:

1. **Default label** = Android `Build.model` (e.g. `moto e13`), editable later
   in تنظیمات as a free Persian/ASCII string («ویترین»).
2. **Backup** carries `installationId` as a **short opaque hash** (truncated /
   keyed hash of the Keystore id), not the raw UUID — enough to group writes,
   useless as a hardware fingerprint.
3. **Priority** = after physical soak (done 2026-11-27) and **before**
   advertising multi-device; can run in parallel with signup reopen packet;
   still behind accountant period-lock sign-off for accounting features.

Implementation remains blocked until the owner explicitly accepts Option B +
these defaults (or substitutes).
