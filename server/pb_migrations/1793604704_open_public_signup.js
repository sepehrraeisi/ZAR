/// Launch: reopen public signup (zar.signup.public=open).
/// Owner authorized 2026-11-28 (`SIGNUP-REOPEN-LAUNCH-PACKET-2026-11-25.md`).
/// Abuse evidence already green (`SIGNUP-LAUNCH-ABUSE-EVIDENCE-2026-11-25.md`).
/// Numbered below restore lineage top `1793604800`.
/// Deploy only with fresh zar-backup + off-site verify + postflight.

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
