/// Security boundary for PocketBase superuser access behind the local Caddy
/// reverse proxy. Caddy replaces X-Zar-Client-IP with the TCP peer address and
/// PocketBase listens on loopback only, so public clients cannot forge it.
migrate((app) => {
  const settings = app.settings();

  settings.trustedProxy.headers = ['X-Zar-Client-IP'];
  settings.trustedProxy.useLeftmostIP = false;
  settings.superuserIPs = ['127.0.0.1', '::1'];

  return app.save(settings);
}, (app) => {
  const settings = app.settings();

  settings.trustedProxy.headers = [];
  settings.trustedProxy.useLeftmostIP = false;
  settings.superuserIPs = [];

  return app.save(settings);
});
