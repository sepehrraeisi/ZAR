/// Route-only cash journal append (CAS/idempotency via zar_write_receipts).
///
/// Clients must use `POST /api/zar/write/cash/append`. Numbered below restore
/// lineage top `1793604800` and after hard-delete lock `1793604700`.

migrate((app) => {
  const cash = app.findCollectionByNameOrId('zar_cash_entries');
  cash.createRule = null;
  // update/delete already null from prior locks; keep the append-only boundary.
  app.save(cash);
}, (app) => {
  const cash = app.findCollectionByNameOrId('zar_cash_entries');
  cash.createRule =
    '@request.auth.id != "" && workspace.members.id ?= @request.auth.id';
  app.save(cash);
});
