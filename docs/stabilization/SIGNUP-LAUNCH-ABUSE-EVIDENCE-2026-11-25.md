# Signup launch abuse / rate-limit evidence (§10.4 launch gate)

تاریخ: 2026-11-25 — شاخه: `feature/signup-launch-abuse-evidence`
سیاست production: `zar.signup.public=closed` (بدون تغییر؛ reopen هنوز نیاز به
migration رو به جلو + تصمیم مالک دارد).

## Goal

قبل از باز کردن ثبت‌نام در لانچ، ثابت شود که rule نسخه‌دار `users:create`
(۵ درخواست / ۶۰۰ ثانیه) واقعاً burst ناشناس را با HTTP 429 قطع می‌کند، روی
instance یکبارمصرف — نه روی production.

## Suite

`server/tests/pocketbase_signup_launch_abuse_test.py` (wired در
`phase_a2_ci.yml` کنار `pocketbase_signup_policy_test.py`):

1. migrate + superuser روی PocketBase disposable
2. assert settings شامل `users:create` با `maxRequests=5`, `duration=600`
3. anonymous create هنوز **403** (createRule null)
4. موقتاً `PATCH /api/collections/users` با `createRule=""` (فقط روی همین instance)
5. burst ۸ anonymous create → حداقل یک **200** و حداقل یک **429**
6. re-close با `createRule=null`؛ GET تأیید null
7. create بعدی **403 یا 429** (هرگز 200) — 429 به‌خاطر پنجره‌ی rate-limit بعد از burst مجاز است

## Local run (2026-11-25)

```text
PASS users:create rate rule present (5 / 600s)
PASS signup still closed before temporary open: HTTP 403
PASS temporary open createRule on disposable instance
PASS signup burst trips rate limit statuses=[200, 200, 200, 200, 429, 429, 429, 429]
PASS createRule null after re-close
PASS signup denied after re-close: HTTP 429
```

Command: `python server/tests/pocketbase_signup_launch_abuse_test.py --pocketbase .tools/pocketbase.exe`

## Production posture

- **بدون** تغییر schema/hook/Caddy روی VPS.
- Public signup همچنان بسته (`SIGNUP-POLICY-CLOSED-EVIDENCE-2026-11-23.md`).
- باز کردن لانچ = migration رو به جلو (`users.createRule = ""` یا rule صریح) +
  این evidence سبز در CI + تصمیم مالک.

## Remaining for launch reopen

- [x] owner decision + forward migration (`1793604704`, PR #77)
- [x] post-deploy anonymous create smoke + rate-limit spot check
      (`SIGNUP-REOPEN-DEPLOY-EVIDENCE-2026-11-28.md`)
- [ ] UI/device QA on APK ≥ 20089 after server open
