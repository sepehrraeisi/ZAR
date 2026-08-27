import 'dart:async';

import 'package:flutter/foundation.dart';

import '../reminders/flutter_local_notification_scheduler.dart';
import '../reminders/record_reminder_registry.dart';
import 'notification_center.dart';
import 'notification_content_policy.dart';
import 'notification_preferences_store.dart';
import 'record_tap_buffer.dart';

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
  ZarNotificationPreferencesStore? _preferencesStore;
  final RecordTapBuffer _recordTaps = RecordTapBuffer();

  ZarNotificationPreferences _preferences = const ZarNotificationPreferences();

  ZarNotificationPreferences get preferences => _preferences;
  String? get pendingRecordId => _recordTaps.pendingRecordId;

  /// Installs the app-level destination for notification taps.
  ///
  /// The shell may replace this handler after login/workspace bootstrap. If a
  /// notification was tapped before the shell became ready, the latest pending
  /// record id is delivered exactly once as soon as a handler is installed.
  void setRecordTapHandler(ValueChanged<String>? handler) {
    _recordTaps.setHandler(handler);
  }

  Future<void> install() async {
    if (kIsWeb) return;
    final preferencesStore = _preferencesStore ??=
        SharedPreferencesNotificationStore();
    RecordReminderRegistry.defaultScheduler = scheduler;
    NotificationSettingsScreen.defaultRequestPermission = requestPermission;
    NotificationSettingsScreen.defaultOpenSystemSettings = openSystemSettings;
    NotificationSettingsScreen.defaultPreferencesChanged = updatePreferences;

    try {
      _preferences = await preferencesStore.load();
    } catch (_) {
      // Device settings are non-authoritative. A corrupt/unavailable preference
      // store must never prevent the business app from starting.
      _preferences = const ZarNotificationPreferences();
    }

    _installPrivacyPolicy();
    await scheduler.initialize();
    await _applyDeliveryPreferences();

    // Capture a cold-start destination immediately. It is buffered until the
    // authenticated/workspace shell registers a navigation handler.
    final initial = await initialRecordId();
    if (initial != null) _recordTaps.add(initial);
  }

  void updatePreferences(ZarNotificationPreferences value) {
    _preferences = value;
    _installPrivacyPolicy();
    unawaited(_persistAndApplyPreferenceChange(value));
  }

  Future<bool> requestPermission() => scheduler.requestPermission();

  Future<bool> openSystemSettings() =>
      scheduler.openSystemNotificationSettings();

  Future<String?> initialRecordId() => scheduler.initialRecordId();

  /// Compatibility helper for callers that explicitly request cold-start
  /// delivery. The buffer prevents the destination from being lost when no
  /// navigation handler is ready yet.
  Future<void> deliverInitialRecordTap() async {
    final recordId = await initialRecordId();
    if (recordId != null) _recordTaps.add(recordId);
  }

  Future<void> _persistAndApplyPreferenceChange(
    ZarNotificationPreferences value,
  ) async {
    final preferencesStore = _preferencesStore;
    try {
      if (preferencesStore != null) {
        await preferencesStore.save(value);
      }
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
    final wantsSound =
        _preferences.enabled &&
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
    _recordTaps.add(recordId);
  }
}
