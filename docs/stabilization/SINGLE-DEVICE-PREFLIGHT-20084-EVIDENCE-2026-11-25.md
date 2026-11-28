# Single-device preflight — APK 20084

تاریخ: 2026-11-25  
مرجع: `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md` (optional single-device section)

## Device / build

- Samsung `SM_N986U` / `R5CN70SG2BF` (unlocked for this session)
- Installed: versionCode **20084**, versionName `1.0.0`
- Workspace session: `shahab@zarplus.cloud` → `https://app.titangold.ir`
  (account card on backup screen)

## Checklist

| Step | Result |
|------|--------|
| 1. Cold start → session restores | **Pass** — force-stop + `am start` landed on home for «گالری طلای مهر» without login |
| 2. Create person; force-stop; reopen | **Pass** — created `SoakPreA1830`; after force-stop/reopen, search shows the person (count «همه ۲») |
| 3. Edit a settlement note; save OK | **Partial** — existing CleanAli receive is **completed** (view-only banner; note `soakQA` not editable). Quick-add cash receive (1000) reached confirm dialog but did not persist (cashbox still ۲۵۰٬۰۰۰); abandoned to avoid polluting workspace while keyboard/confirm loop blocked automation |
| 4. Backup screen: email + server URL | **Pass** — «پشتیبان‌گیری و داده‌ها» shows `shahab@zarplus.cloud` and `https://app.titangold.ir`; no export performed |

## Multi-device gate

- At evidence time `adb devices` still listed **only** `R5CN70SG2BF`.
- Second physical phone was reported connected by the owner but did **not**
  appear as an ADB device (likely USB debugging not authorized / charging-only
  mode). Pair soak remains blocked until device B shows `device` in `adb devices -l`.

## Result

- **Pass with note** on optional single-device preflight (steps 1, 2, 4 solid;
  step 3 partial due to no open editable settlement + quick-add automation miss).
- **Not a substitute** for the two-device physical soak gate.

Observer: agent (adb + uiautomator). Pass/Fail: **Pass (partial step 3)**.
