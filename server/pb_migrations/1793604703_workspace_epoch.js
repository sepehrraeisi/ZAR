/// Workspace epoch for consistent multi-collection snapshot reads (ZAR-DATA-006).
///
/// `epoch` advances on every successful domain mutation so
/// `GET /api/zar/read/snapshot` can retry until a non-mixed view is observed.
/// Numbered below restore lineage top `1793604800`.

migrate((app) => {
  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  if (!workspaces.fields.getByName('epoch')) {
    workspaces.fields.add(
      new Field({
        name: 'epoch',
        type: 'number',
        required: false,
        onlyInt: true,
        min: 0,
      }),
    );
    app.save(workspaces);
  }

  const rows = app.findRecordsByFilter('zar_workspaces', '', '-id', 5000, 0);
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const current = row.get('epoch');
    if (
      current === null ||
      current === undefined ||
      current === ''
    ) {
      row.set('epoch', 0);
      app.save(row);
    }
  }
}, (app) => {
  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  const field = workspaces.fields.getByName('epoch');
  if (field) {
    workspaces.fields.removeById(field.id);
    app.save(workspaces);
  }
});
