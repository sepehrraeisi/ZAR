/// Security hardening: workspace containers are never deleted through the
/// normal record API. Only an explicit superuser/maintenance procedure may
/// remove a workspace after its dependent data has been handled.
migrate((app) => {
  const collection = app.findCollectionByNameOrId('zar_workspaces');
  collection.deleteRule = null;
  return app.save(collection);
}, (app) => {
  // Deliberately preserve the security boundary during rollback. The
  // application has no supported workspace-delete operation.
  const collection = app.findCollectionByNameOrId('zar_workspaces');
  collection.deleteRule = null;
  return app.save(collection);
});
