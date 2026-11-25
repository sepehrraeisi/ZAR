# ADR — Local SQLite encryption (ZAR-MOB-001 remainder)

تاریخ: 2026-11-25  
وضعیت: **Proposed — needs owner decision** (no code change in this doc)

## Context

- Session token is Keystore-backed (`ZarSecureTokenStore`).
- Android Auto Backup / device-transfer of app data is denied
  (`ANDROID-BACKUP-DENY-EVIDENCE-2026-11-25.md`).
- Local Drift DB (`zar_plus_local`) remains plaintext on device storage.
- Lost/unlocked phone or physical extraction can still expose local shop data.

## Options

| Option | Approach | Pros | Cons |
|---|---|---|---|
| **A. SQLCipher / encrypted Drift** | Encrypt DB file with passphrase derived from Android Keystore | Strong at-rest protection | Migration of existing installs; backup/export story; package size; Drift integration care |
| **B. Keep plaintext + backup deny** | Rely on deny rules + device lock | Already shipped; zero UX change | Weak against rooted extraction / unlocked device |
| **C. Encrypt only sensitive columns** | Field-level crypto in app layer | Smaller blast radius | Complex; easy to miss fields; query/filter pain |

## Recommendation (engineering)

Prefer **A** after owner accepts:

1. One-time on-device migration from plaintext → encrypted DB on first launch
   after the shipping APK.
2. Key material only in Android Keystore (no passphrase UI for shopkeepers).
3. Cloud remains source of truth for multi-device; local encrypted DB is cache/
   offline.
4. Export JSON stays plaintext-by-design until a separate tamper-evident export
   policy is approved (out of scope here).

## Decision needed from owner

- Approve Option A (or explicitly keep B until after launch)?
- Accept one forced local re-sync / cold-start risk for existing installs?
- Timeline: before advertising cloud reliability, or post-launch hardening?

## Non-goals

- Encrypting cloud PocketBase data-at-rest on VPS (separate ops track)
- Changing backup JSON format in the same change

## Next engineering step (after approval)

Spike branch: Drift + SQLCipher (or `sqflite_sqlcipher`) on Android-only,
migration test with fixture DB, evidence doc, then device QA APK.
