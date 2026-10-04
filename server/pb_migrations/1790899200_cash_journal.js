// V8 backup cash journal. Apply before deploying the new Android client.
migrate((app) => {
  const workspace = app.findCollectionByNameOrId('zar_workspaces');
  const rule = '@request.auth.id != "" && workspace.members.id ?= @request.auth.id';
  app.save(new Collection({
    name: 'zar_cash_entries', type: 'base',
    listRule: rule, viewRule: rule, createRule: rule,
    updateRule: null, deleteRule: rule,
    fields: [
      {name: 'id', type: 'text', required: true, primaryKey: true,
        autogeneratePattern: '[a-z0-9]{15}', pattern: '^[A-Za-z0-9_-]+$', min: 2, max: 255},
      {name: 'workspace', type: 'relation', required: true, maxSelect: 1, collectionId: workspace.id},
      {name: 'data', type: 'json', required: true},
    ],
  }));
}, (app) => app.delete(app.findCollectionByNameOrId('zar_cash_entries')));
