# Single-device preflight — APK 20084 (partial)

تاریخ: 2026-11-25  
مرجع: `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md` (optional single-device section)

## Device / build

- Samsung `SM_N986U` / `R5CN70SG2BF`
- Installed: versionCode **20084**, versionName `1.0.0`
- `lastUpdateTime=2026-11-25 15:47:39` (from Device QA install)

## Steps executed (adb)

1. `dumpsys package` confirmed **20084**
2. `am force-stop com.zarplus.app`
3. `am start -n com.zarplus.app/.MainActivity` → started / later
   «intent delivered to currently running top-most instance»

## Blocked

- Device was on AOD/charging lock UI (`78%` / «until full»); interactive
  people/settlement/backup steps were **not** completed in this session.
- Full optional preflight (create person, force-stop reopen, backup account
  card) needs an unlocked screen and owner taps (Persian `adb input text`
  limitation remains).

## Result

- **Partial pass**: build identity + cold-start launch path verified.
- **Not a substitute** for the two-device physical soak gate.
- Next: unlock + finish checklist steps 1–4, or attach second device/emulator
  for the pair soak.

Observer: agent (adb-only). Pass/Fail: **Partial**.
