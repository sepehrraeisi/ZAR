/// Route-only workspace creation for atomic bootstrap.
///
/// Clients must use `POST /api/zar/bootstrap/workspace` so create+pin is
/// transactional. Numbered below restore lineage top `1793604800`.

migrate((app) => {
  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  workspaces.createRule = null;
  app.save(workspaces);
}, (app) => {
  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  workspaces.createRule =
    '@request.auth.id != "" && members.id ?= @request.auth.id';
  app.save(workspaces);
});
