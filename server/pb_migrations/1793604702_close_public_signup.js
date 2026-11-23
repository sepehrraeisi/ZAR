/// Versioned public-signup policy: CLOSED until launch (§10.4).
///
/// Owner decision (HANDOFF / ROADMAP): public user creation stays denied.
/// Only superusers may create `users` rows (seeding / ops). Numbered below
/// restore lineage top `1793604800`.
///
/// Policy id: `zar.signup.public=closed` (2026-11-23). Re-opening requires a
/// new forward migration + abuse/rate-limit evidence — do not loosen this
/// down-migration.

migrate((app) => {
  const users = app.findCollectionByNameOrId('users');
  users.createRule = null;
  app.save(users);
}, (app) => {
  // Preserve the closed boundary on rollback (same spirit as workspace delete).
  const users = app.findCollectionByNameOrId('users');
  users.createRule = null;
  app.save(users);
});
