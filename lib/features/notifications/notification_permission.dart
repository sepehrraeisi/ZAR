/// The operating-system notification state as observed at runtime.
///
/// This is deliberately separate from ZAR+'s own notification preference.
/// The latter controls whether the app schedules reminders; this value is
/// always read from the platform and may change while the app is backgrounded.
enum ZarNotificationPermissionStatus {
  unsupported,
  notDetermined,
  granted,
  provisional,
  denied,
  disabled,
}

class ZarNotificationPermissionState {
  const ZarNotificationPermissionState(this.status);

  const ZarNotificationPermissionState.unsupported()
    : status = ZarNotificationPermissionStatus.unsupported;
  const ZarNotificationPermissionState.notDetermined()
    : status = ZarNotificationPermissionStatus.notDetermined;
  const ZarNotificationPermissionState.granted()
    : status = ZarNotificationPermissionStatus.granted;
  const ZarNotificationPermissionState.provisional()
    : status = ZarNotificationPermissionStatus.provisional;
  const ZarNotificationPermissionState.denied()
    : status = ZarNotificationPermissionStatus.denied;
  const ZarNotificationPermissionState.disabled()
    : status = ZarNotificationPermissionStatus.disabled;

  final ZarNotificationPermissionStatus status;

  bool get isGranted =>
      status == ZarNotificationPermissionStatus.granted ||
      status == ZarNotificationPermissionStatus.provisional;

  bool get isRequestable =>
      status == ZarNotificationPermissionStatus.notDetermined;

  bool get shouldOpenSettings =>
      status == ZarNotificationPermissionStatus.denied ||
      status == ZarNotificationPermissionStatus.disabled;
}
