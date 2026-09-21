/// PocketBase migration: ZAR+ workspace collections.
///
/// Applied automatically on `pocketbase serve` start. Each record stores its
/// full domain payload (the tested V7 backup per-entity JSON) in the `data`
/// JSON field plus a `workspace` relation — the client keeps the typed domain
/// model, the server stays schema-simple and provider-neutral.
///
/// Access model: every record belongs to a `zar_workspaces` row whose
/// `members` field lists the authorized user IDs; the rules below only let
/// workspace members read/write their own workspace rows.
//
// The PocketBase JSVM has no async/await; the migration API is synchronous.
migrate((app) => {
  const memberRule =
    '@request.auth.id != "" && workspace.members.id ?= @request.auth.id';

  // Allow the PocketBase batch endpoint so restore can run transactionally.
  const settings = app.settings();
  settings.batch.enabled = true;
  settings.batch.maxRequests = 500;
  app.save(settings);

  const idField = {
    name: 'id',
    type: 'text',
    required: true,
    primaryKey: true,
    autogeneratePattern: '[a-z0-9]{15}',
    hidden: false,
    pattern: '^[A-Za-z0-9_-]+$',
    min: 2,
    max: 255,
  };
  const dataField = { name: 'data', type: 'json', required: true };

  const workspace = new Collection({
    name: 'zar_workspaces',
    type: 'base',
    listRule: '@request.auth.id != "" && members.id ?= @request.auth.id',
    viewRule: '@request.auth.id != "" && members.id ?= @request.auth.id',
    createRule: '@request.auth.id != "" && members.id ?= @request.auth.id',
    updateRule: '@request.auth.id != "" && members.id ?= @request.auth.id',
    deleteRule: '',
    fields: [
      Object.assign({}, idField),
      { name: 'displayName', type: 'text', required: true },
      {
        name: 'members',
        type: 'relation',
        required: true,
        collectionId: '_pb_users_auth_',
        maxSelect: 999,
      },
      { name: 'createdAt', type: 'autodate', onCreate: true },
    ],
    indexes: [
      'CREATE UNIQUE INDEX idx_zar_workspaces_id ON zar_workspaces (id)',
    ],
  });
  app.save(workspace);

  // The signed-in user points at its workspace, so the client learns the
  // workspace id straight from its own auth record. This must come after the
  // workspace collection exists — the relation targets it.
  const users = app.findCollectionByNameOrId('users');
  users.fields.add(
    new Field({
      name: 'workspace',
      type: 'relation',
      required: false,
      collectionId: workspace.id,
      maxSelect: 1,
    }),
  );
  app.save(users);

  const collections = {
    zar_people: 'person_id',
    zar_deals: 'deal_id',
    zar_settlements: 'settlement_id',
    zar_coin_types: 'coin_type_id',
    zar_currency_types: 'currency_type_id',
    zar_allocations: 'allocation_id',
  };

  for (const name of Object.keys(collections)) {
    app.save(
      new Collection({
        name: name,
        type: 'base',
        listRule: memberRule,
        viewRule: memberRule,
        createRule: memberRule,
        updateRule: memberRule,
        deleteRule: memberRule,
        fields: [
          Object.assign({}, idField),
          Object.assign(
            { name: 'workspace', type: 'relation', required: true, maxSelect: 1 },
            { collectionId: workspace.id },
          ),
          Object.assign({}, dataField),
        ],
        indexes: [
          'CREATE UNIQUE INDEX idx_' + name + '_id ON ' + name + ' (workspace, id)',
        ],
      }),
    );
  }
}, (app) => {
  const names = [
    'zar_people',
    'zar_deals',
    'zar_settlements',
    'zar_coin_types',
    'zar_currency_types',
    'zar_allocations',
    'zar_workspaces',
  ];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    if (collection) {
      app.delete(collection);
    }
  }
});
