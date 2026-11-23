/// Consistent workspace snapshot route (ZAR-DATA-006).

routerAdd(
  'GET',
  '/api/zar/read/snapshot',
  (e) => {
    const read = require(`${__hooks}/zar_read.js`);
    return read.snapshot(e);
  },
  $apis.requireAuth('users'),
);
