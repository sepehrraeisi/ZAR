/// Atomic allocation replace + lock Record API mutations on zar_allocations.
///
/// Client delete+create batches are replaced by `/api/zar/write/allocations/replace`
/// (CAS on before-hash + idempotency + audit payload in zar_write_receipts).
/// Numbered below restore lineage top `1793604800`.

migrate((app) => {
  const allocations = app.findCollectionByNameOrId('zar_allocations');
  // Route-only writes: members may still list/view workspace rows.
  allocations.createRule = null;
  allocations.updateRule = null;
  allocations.deleteRule = null;
  app.save(allocations);
}, (app) => {
  const memberRule =
    '@request.auth.id != "" && workspace.members.id ?= @request.auth.id'; // restore pre-lock member CRUD
  const allocations = app.findCollectionByNameOrId('zar_allocations');
  allocations.createRule = memberRule;
  allocations.updateRule = memberRule;
  allocations.deleteRule = memberRule;
  app.save(allocations);
});
