# Signup reopen — launch packet (§10.4)

وضعیت: **آماده برای تصمیم مالک — هنوز deploy / merge کد بازکننده نشده**

پیش‌نیازهای evidence: `SIGNUP-POLICY-CLOSED-EVIDENCE-2026-11-23.md`،
`SIGNUP-LAUNCH-ABUSE-EVIDENCE-2026-11-25.md` (suite سبز در CI).

## وقتی مالک گفت «لانچ»

### 1) Migration رو به جلو (شماره زیر `1793604800`)

فایل پیشنهادی: `server/pb_migrations/1793604704_open_public_signup.js`

```js
/// Launch: reopen public signup (zar.signup.public=open).
/// Apply only after owner decision. Abuse evidence already green.
/// Numbered below restore lineage top 1793604800.

migrate((app) => {
  const users = app.findCollectionByNameOrId('users');
  // Empty string = public create (PocketBase open marker).
  users.createRule = '';
  app.save(users);
}, (app) => {
  // Rollback returns to closed (null), matching 1793604702 policy.
  const users = app.findCollectionByNameOrId('users');
  users.createRule = null;
  app.save(users);
});
```

### 2) Client UI

در `ZarAuthGate` دوباره `onSignUp` را به `LoginScreen` بده:

```dart
onSignUp: (email, password) =>
    service.signUp(email: email, password: password),
```

APK جدید با build-number صعودی.

### 3) Tests / CI قبل از merge

- `pocketbase_signup_policy_test.py` را به «باز» به‌روز کن (anonymous create 200)
- `pocketbase_signup_launch_abuse_test.py` همچنان burst→429 را ثابت کند
- lineage pin برای `1793604704` اضافه شود

### 4) Deploy discipline

1. fresh `zar-backup` + off-site verify  
2. stop → migrate up → schema: `users.createRule` empty  
3. start → anonymous create smoke + 429 after 5 creates  
4. evidence doc + HANDOFF §0

**تا دستور صریح مالک این migration را روی production اجرا نکن.**
