/// PocketBase serializes every route handler into an isolated program. Load the
/// immutable helper module inside each handler so no mutable state is shared.

routerAdd('GET', '/api/zar/restore/state', (e) => {
  const restore = require(`${__hooks}/zar_restore.js`);
  return restore.state(e);
}, $apis.requireAuth('users'));

routerAdd('POST', '/api/zar/restore/commit', (e) => {
  const restore = require(`${__hooks}/zar_restore.js`);
  return restore.commit(e);
}, $apis.requireAuth('users'), $apis.bodyLimit(8 * 1024 * 1024));
