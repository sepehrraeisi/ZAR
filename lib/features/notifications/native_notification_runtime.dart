import 'dart:async';

import 'package:flutter/foundation.dart';

import '../reminders/flutter_local_notification_scheduler.dart';
import '../reminders/record_reminder_registry.dart';
import 'notification_center.dart';
import 'notification_content_policy.dart';
import 'notification_preferences_store.dart';

/// App-level native notification runtime.
///
/// It installs the native scheduler without prompting for permissions. Permission
/// requests remain an explicit user action from Notification Settings.
class ZarNativeNotificationRuntime {
  ZarNativeNotificationRuntime._() {
    scheduler = FlutterLocalNotificationScheduler(
      onRecordTapped: _handleRecordTapped,
    );
  }

  static final ZarNativeNotificationRuntime instance =
      ZarNativeNotificationRuntime._();

  late final FlutterLocalNotificationScheduler scheduler;
  final ZarNotificationPreferencesStore _preferencesStore =
      SharedPreferencesNotificationStore();

  ZarNotificationPreferences _preferences = const ZarNotificationPreferences();
  ValueChanged<String>? _recordTapHandler;

  ZarNotificationPreferences get preferences => _preferences;

  /// Installs the app-level destination for notification taps.
  ///
  /// The shell may replace this handler after login/workspace bootstrap. Both a
  /// live notification response and a cold-start launch can be forwarded here.
  void setRecordTapHandler(ValueChanged<String>? handler) {
    _recordTapHandler = handler;
  }

  Future<void> install() async {
    if (kIsWeb) return;
    RecordReminderRegistry.defaultScheduler = scheduler;
    NotificationSettingsScreen.defaultRequestPermission = requestPermission;
    NotificationSettingsScreen.defaultOpenSystemSettings = openSystemSettings;
    NotificationSettingsScreen.defaultPreferencesChanged = updatePreferences;

    try {
      _preferences = await _preferencesStore.load();
    } catch (_) {
      // Device settings are non-authoritative. A corrupt/unavailable preference
      // store must never prevent the business app from starting.
      _preferences = const ZarNotificationPreferences();
    }

    _installPrivacyPolicy();
    await scheduler.initialize();
    await _applyDeliveryPreferences();
  }

  void updatePreferences(ZarNotificationPreferences value) {
    _preferences = value;
    _installPrivacyPolicy();
    unawaited(_persistAndApplyPreferenceChange(value));
  }

  Future<bool> requestPermission() => scheduler.requestPermission();

  Future<bool> openSystemSettings() => scheduler.openSystemNotificationSettings();

  Future<String?> initialRecordId() => scheduler.initialRecordId();

  /// Delivers the cold-start notification destination once the shell has
  /// installed a record tap handler.
  Future<void> deliverInitialRecordTap() async {
    final recordId = await initialRecordId();
    if (recordId != null) _handleRecordTapped(recordId);
  }

  Future<void> _persistAndApplyPreferenceChange(
    ZarNotificationPreferences value,
  ) async {
    try {
      await _preferencesStore.save(value);
    } catch (_) {
      // A preference write failure must not roll back or block business data.
      // The current session still honors the selected setting.
    }
    await _applyPreferenceChange();
  }

  Future<void> _applyPreferenceChange() async {
    await _applyDeliveryPreferences();
    // Rebuild already-pending title/body after a privacy change. This prevents
    // an old Full/Limited notification from lingering after the user switches
    // to Private mode.
    await RecordReminderRegistry.refreshAllScheduledContent();
  }

  Future<void> _applyDeliveryPreferences() async {
    final wantsSound = _preferences.enabled &&
        _preferences.soundEnabled &&
        _preferences.soundProfile != NotificationSoundProfile.silent;
    await scheduler.configure(
      enabled: _preferences.enabled,
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

  void _handleRecordTapped(String recordId) {
    _recordTapHandler?.call(recordId);
  }
}
