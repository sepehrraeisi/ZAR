/// <reference path="../pb_data/types.d.ts" />

// Cash journal corrections must be represented by reversal records. Never
// reopen hard deletion from a rollback path because that would reintroduce
// silent destruction of accounting history.
migrate((app) => {
  const collection = app.findCollectionByNameOrId('zar_cash_entries');
  collection.deleteRule = null;
  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId('zar_cash_entries');
  collection.deleteRule = null;
  return app.save(collection);
});
