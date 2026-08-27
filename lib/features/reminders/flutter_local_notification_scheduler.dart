import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';
import 'reminder_scheduler.dart';

/// Native iOS/Android implementation of [ReminderScheduler].
///
/// Permission prompts are intentionally deferred: [initialize] never asks for
/// notification permission. The UI must call [requestPermission] only after an
/// explicit user action such as «فعال‌کردن اعلان‌ها».
class FlutterLocalNotificationScheduler implements ReminderScheduler {
  FlutterLocalNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.timeZoneName = 'Asia/Tehran',
    bool playSound = true,
    bool enableVibration = true,
    this.onRecordTapped,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _playSound = playSound,
        _enableVibration = enableVibration;

  static const _soundChannelId = 'zar_reminders_sound';
  static const _silentChannelId = 'zar_reminders_silent';
  static const _channelName = 'یادآوری‌های ZAR+';
  static const _channelDescription = 'یادآوری تحویل، دریافت و تعهدات کاری';
  static const _payloadPrefix = 'zar-record:';

  final FlutterLocalNotificationsPlugin _plugin;
  final String timeZoneName;
  final ValueChanged<String>? onRecordTapped;

  bool _playSound;
  bool _enableVibration;
  bool _initialized = false;
  late tz.Location _location;

  bool get initialized => _initialized;
  bool get playSound => _playSound;
  bool get enableVibration => _enableVibration;

  void configure({required bool playSound, required bool enableVibration}) {
    _playSound = playSound;
    _enableVibration = enableVibration;
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tzdata.initializeTimeZones();
    _location = tz.getLocation(timeZoneName);

    const android = AndroidInitializationSettings('ic_launcher');
    const ios = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final recordId = _recordIdFromPayload(response.payload);
        if (recordId != null) onRecordTapped?.call(recordId);
      },
    );
    _initialized = true;
  }

  /// Requests the OS notification permission after an explicit user action.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: _playSound,
          ) ??
          false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  Future<bool> openSystemNotificationSettings() async {
    if (kIsWeb) return false;
    await initialize();
    return await _plugin.openAppNotificationSettings() ?? false;
  }

  /// Returns a record id if the application was launched by tapping one of our
  /// local reminders. Call this after [initialize] during native app startup.
  Future<String?> initialRecordId() async {
    if (kIsWeb) return null;
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return _recordIdFromPayload(details?.notificationResponse?.payload);
  }

  @override
  Future<void> replaceForRecord({
    required String recordId,
    required DateTime dueAt,
    required ReminderPlan plan,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await cancelForRecord(recordId);

    final now = DateTime.now().toUtc();
    for (final fireAt in plan.resolveTimes(dueAt)) {
      final utc = fireAt.toUtc();
      if (!utc.isAfter(now)) continue;

      final channelId = _playSound ? _soundChannelId : _silentChannelId;
      await _plugin.zonedSchedule(
        id: _stableNotificationId(recordId, utc),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(utc, _location),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: _playSound,
            enableVibration: _enableVibration,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: _playSound,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix$recordId',
      );
    }
  }

  @override
  Future<void> cancelForRecord(String recordId) async {
    if (kIsWeb) return;
    await initialize();
    final payload = '$_payloadPrefix$recordId';
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending.where((item) => item.payload == payload)) {
      await _plugin.cancel(id: request.id);
    }
  }

  @override
  Future<List<ScheduledReminder>> pendingForRecord(String recordId) async {
    // The native plugin exposes pending ids/title/body but not the resolved
    // schedule timestamp consistently on every platform. Business logic should
    // remain sourced from ReminderPlan; deterministic schedule assertions use
    // InMemoryReminderScheduler in tests and web preview.
    return const [];
  }

  static String? _recordIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final id = payload.substring(_payloadPrefix.length);
    return id.isEmpty ? null : id;
  }

  static int _stableNotificationId(String recordId, DateTime scheduledAt) {
    // Stable 31-bit FNV-1a. Dart String.hashCode is not a persistence contract.
    var hash = 0x811c9dc5;
    final value = '$recordId:${scheduledAt.toUtc().millisecondsSinceEpoch}';
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
