import 'package:flutter/foundation.dart';

import '../reminders/flutter_local_notification_scheduler.dart';
import '../reminders/record_reminder_registry.dart';
import 'notification_center.dart';
import 'notification_content_policy.dart';

/// App-level native notification runtime.
///
/// It installs the native scheduler without prompting for permissions. Permission
/// requests remain an explicit user action from Notification Settings.
class ZarNativeNotificationRuntime {
  ZarNativeNotificationRuntime._();

  static final ZarNativeNotificationRuntime instance =
      ZarNativeNotificationRuntime._();

  final FlutterLocalNotificationScheduler scheduler =
      FlutterLocalNotificationScheduler();

  ZarNotificationPreferences _preferences = const ZarNotificationPreferences();

  ZarNotificationPreferences get preferences => _preferences;

  Future<void> install() async {
    if (kIsWeb) return;
    RecordReminderRegistry.defaultScheduler = scheduler;
    NotificationSettingsScreen.defaultRequestPermission = requestPermission;
    NotificationSettingsScreen.defaultOpenSystemSettings = openSystemSettings;
    NotificationSettingsScreen.defaultPreferencesChanged = updatePreferences;
    _applyDeliveryPreferences();
    _installPrivacyPolicy();
    // Initialization is safe because the adapter defers permission prompts.
    await scheduler.initialize();
  }

  void updatePreferences(ZarNotificationPreferences value) {
    _preferences = value;
    _applyDeliveryPreferences();
    _installPrivacyPolicy();
  }

  Future<bool> requestPermission() => scheduler.requestPermission();

  Future<bool> openSystemSettings() => scheduler.openSystemNotificationSettings();

  Future<String?> initialRecordId() => scheduler.initialRecordId();

  void _applyDeliveryPreferences() {
    final wantsSound = _preferences.enabled &&
        _preferences.soundEnabled &&
        _preferences.soundProfile != NotificationSoundProfile.silent;
    scheduler.configure(
      playSound: wantsSound,
      enableVibration: _preferences.enabled && _preferences.vibrationEnabled,
    );
  }

  void _installPrivacyPolicy() {
    const policy = ZarNotificationContentPolicy();
    RecordReminderRegistry.defaultContentBuilder = (record, personName) {
      final content = policy.forRecord(
        record: record,
        personName: personName,
        privacy: _preferences.privacy,
      );
      return ReminderNotificationContent(
        title: content.title,
        body: content.body,
      );
    };
  }
}
