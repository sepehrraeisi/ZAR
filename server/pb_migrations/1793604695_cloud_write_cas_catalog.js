/// Cloud write CAS slice 2 — revision on coin/currency catalog collections.
///
/// Extends `/api/zar/write/upsert` coverage to `zar_coin_types` and
/// `zar_currency_types`. Numbered below `1793604800_transactional_restore.js`
/// and after slice 1 (`1793604690`) so restore stays the lineage top.

migrate((app) => {
  const names = ['zar_coin_types', 'zar_currency_types'];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    if (!collection.fields.getByName('revision')) {
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
}, (app) => {
  const names = ['zar_coin_types', 'zar_currency_types'];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    const field = collection.fields.getByName('revision');
    if (field) {
      collection.fields.removeById(field.id);
      app.save(collection);
    }
  }
});
