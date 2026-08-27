import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';
import 'reminder_scheduler.dart';

class _NativeReminderSpec {
  const _NativeReminderSpec({
    required this.recordId,
    required this.dueAt,
    required this.plan,
    required this.title,
    required this.body,
  });

  final String recordId;
  final DateTime dueAt;
  final ReminderPlan plan;
  final String title;
  final String body;
}

/// Native iOS/Android implementation of [ReminderScheduler].
///
/// Permission prompts are intentionally deferred: [initialize] never asks for
/// notification permission. The UI must call [requestPermission] only after an
/// explicit user action such as «فعال‌کردن اعلان‌ها».
class FlutterLocalNotificationScheduler implements ReminderScheduler {
  FlutterLocalNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.timeZoneName = 'Asia/Tehran',
    bool enabled = true,
    bool playSound = true,
    bool enableVibration = true,
    this.onRecordTapped,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _enabled = enabled,
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
  final Map<String, _NativeReminderSpec> _specs = {};

  bool _enabled;
  bool _playSound;
  bool _enableVibration;
  bool _initialized = false;
  late tz.Location _location;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get playSound => _playSound;
  bool get enableVibration => _enableVibration;

  /// Applies app-level delivery preferences. Disabling notifications removes
  /// native pending requests but keeps the business reminder plans in memory;
  /// re-enabling schedules those plans again.
  Future<void> configure({
    required bool enabled,
    required bool playSound,
    required bool enableVibration,
  }) async {
    _enabled = enabled;
    _playSound = playSound;
    _enableVibration = enableVibration;
    if (kIsWeb) return;
    await initialize();

    if (!_enabled) {
      await _plugin.cancelAllPendingNotifications();
      return;
    }

    final specs = List<_NativeReminderSpec>.from(_specs.values);
    await _plugin.cancelAllPendingNotifications();
    for (final spec in specs) {
      await _scheduleSpec(spec);
    }
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
    final spec = _NativeReminderSpec(
      recordId: recordId,
      dueAt: dueAt,
      plan: plan,
      title: title,
      body: body,
    );
    _specs[recordId] = spec;
    if (kIsWeb) return;
    await initialize();
    await _cancelNativeForRecord(recordId);
    if (_enabled) await _scheduleSpec(spec);
  }

  Future<void> _scheduleSpec(_NativeReminderSpec spec) async {
    final now = DateTime.now().toUtc();
    for (final fireAt in spec.plan.resolveTimes(spec.dueAt)) {
      final utc = fireAt.toUtc();
      if (!utc.isAfter(now)) continue;

      final channelId = _playSound ? _soundChannelId : _silentChannelId;
      await _plugin.zonedSchedule(
        id: _stableNotificationId(spec.recordId, utc),
        title: spec.title,
        body: spec.body,
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
        payload: '$_payloadPrefix${spec.recordId}',
      );
    }
  }

  @override
  Future<void> cancelForRecord(String recordId) async {
    _specs.remove(recordId);
    if (kIsWeb) return;
    await initialize();
    await _cancelNativeForRecord(recordId);
  }

  Future<void> _cancelNativeForRecord(String recordId) async {
    final payload = '$_payloadPrefix$recordId';
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending.where((item) => item.payload == payload)) {
      await _plugin.cancel(id: request.id);
    }
  }

  @override
  Future<List<ScheduledReminder>> pendingForRecord(String recordId) async {
    return const [];
  }

  static String? _recordIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final id = payload.substring(_payloadPrefix.length);
    return id.isEmpty ? null : id;
  }

  static int _stableNotificationId(String recordId, DateTime scheduledAt) {
    var hash = 0x811c9dc5;
    final value = '$recordId:${scheduledAt.toUtc().millisecondsSinceEpoch}';
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
