/// Server-side invariant: financial/history rows are never hard-deleted
/// through the Record API. The client corrects history with reversal
/// semantics and never deletes these rows; a compromised client must not be
/// able to either.
///
/// zar_allocations is deliberately exempt: the client's allocation-editing
/// flow replaces a movement's rows atomically (delete + create inside one
/// batch transaction). Tightening that path is a separate audited workstream.
migrate((app) => {
  const names = [
    'zar_people',
    'zar_deals',
    'zar_settlements',
    'zar_coin_types',
    'zar_currency_types',
  ];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    if (collection.deleteRule !== null) {
      collection.deleteRule = null; // null = superusers only; Record API denied
      app.save(collection);
    }
  }
}, (app) => {
  const memberRule =
    '@request.auth.id != "" && workspace.members.id ?= @request.auth.id';
  const names = [
    'zar_people',
    'zar_deals',
    'zar_settlements',
    'zar_coin_types',
    'zar_currency_types',
  ];
  for (const name of names) {
    const collection = app.findCollectionByNameOrId(name);
    collection.deleteRule = memberRule;
    app.save(collection);
  }
});
