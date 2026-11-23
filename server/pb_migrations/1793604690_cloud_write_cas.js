/// Cloud write CAS + idempotency receipts for ordinary upserts.
///
/// Adds a top-level `revision` field to people/deals/settlements and a private
/// `zar_write_receipts` collection used by `/api/zar/write/upsert`.
/// Numbered below `1793604800_transactional_restore.js` so restore stays the
/// lineage top (forward-only after the first restore receipt).

migrate((app) => {
  const names = ['zar_people', 'zar_deals', 'zar_settlements'];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    if (!collection.fields.getByName('revision')) {
      // Not required at the schema layer so legacy Record API creates used by
      // disposable tests still validate; request hooks / upsert route always
      // persist revision >= 1 before save.
      collection.fields.add(
        new Field({
          name: 'revision',
          type: 'number',
          required: false,
          onlyInt: true,
          min: 1,
        }),
      );
      app.save(collection);
    }

    const rows = app.findRecordsByFilter(name, '', '-id', 5000, 0);
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const current = row.get('revision');
      if (
        current === null ||
        current === undefined ||
        current === 0 ||
        current === ''
      ) {
        row.set('revision', 1);
        app.save(row);
      }
    }
  }

  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  const users = app.findCollectionByNameOrId('users');

  let receipts;
  try {
    receipts = app.findCollectionByNameOrId('zar_write_receipts');
  } catch (_) {
    receipts = null;
  }
  if (!receipts) {
    app.save(
      new Collection({
        name: 'zar_write_receipts',
        type: 'base',
        listRule: null,
        viewRule: null,
        createRule: null,
        updateRule: null,
        deleteRule: null,
        fields: [
          {
            name: 'id',
            type: 'text',
            required: true,
            primaryKey: true,
            autogeneratePattern: '[a-f0-9]{32}',
            pattern: '^[a-f0-9]{32}$',
            min: 32,
            max: 32,
          },
          {
            name: 'workspace',
            type: 'relation',
            required: true,
            maxSelect: 1,
            collectionId: workspaces.id,
          },
          {
            name: 'actor',
            type: 'relation',
            required: true,
            maxSelect: 1,
            collectionId: users.id,
          },
          {
            name: 'idempotencyKey',
            type: 'text',
            required: true,
            pattern: '^[A-Za-z0-9_-]{16,128}$',
            min: 16,
            max: 128,
          },
          {
            name: 'collection',
            type: 'text',
            required: true,
            pattern: '^[a-z_]+$',
            min: 3,
            max: 64,
          },
          {
            name: 'recordId',
            type: 'text',
            required: true,
            pattern: '^[A-Za-z0-9_-]{2,255}$',
            min: 2,
            max: 255,
          },
          {
            name: 'requestHash',
            type: 'text',
            required: true,
            pattern: '^[a-f0-9]{64}$',
            min: 64,
            max: 64,
          },
          {
            name: 'responseRevision',
            type: 'number',
            required: true,
            onlyInt: true,
            min: 1,
          },
          { name: 'responseRecord', type: 'json', required: true },
          { name: 'created', type: 'autodate', onCreate: true },
        ],
        indexes: [
          'CREATE UNIQUE INDEX idx_zar_write_receipts_workspace_key ON zar_write_receipts (workspace, idempotencyKey)',
          'CREATE INDEX idx_zar_write_receipts_workspace_created ON zar_write_receipts (workspace, created)',
        ],
      }),
    );
  }
}, (app) => {
  if (
    app.findRecordsByFilter('zar_write_receipts', '', 'id', 1, 0).length > 0
  ) {
    throw new Error(
      'Refusing to remove cloud write CAS after a write receipt exists.',
    );
  }

  try {
    const receipts = app.findCollectionByNameOrId('zar_write_receipts');
    if (receipts) {
      app.delete(receipts);
    }
  } catch (_) {
    // already absent
  }

  const names = ['zar_people', 'zar_deals', 'zar_settlements'];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    const field = collection.fields.getByName('revision');
    if (field) {
      collection.fields.removeById(field.id);
      app.save(collection);
    }
  }
});
