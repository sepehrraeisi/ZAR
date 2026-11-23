/// Atomic workspace bootstrap route.

routerAdd(
  'POST',
  '/api/zar/bootstrap/workspace',
  (e) => {
    const bootstrap = require(`${__hooks}/zar_bootstrap.js`);
    return bootstrap.bootstrapWorkspace(e);
  },
  $apis.requireAuth('users'),
  $apis.bodyLimit(64 * 1024),
);
