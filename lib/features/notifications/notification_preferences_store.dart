import 'package:shared_preferences/shared_preferences.dart';

import 'notification_center.dart';

abstract interface class ZarNotificationPreferencesStore {
  Future<ZarNotificationPreferences> load();

  Future<void> save(ZarNotificationPreferences value);
}

/// Device-local preference persistence.
///
/// These values are UX/device settings, not authoritative business data, so
/// SharedPreferences is appropriate here. Deals, people and settlements remain
/// in the production repository / Firestore source of truth.
class SharedPreferencesNotificationStore
    implements ZarNotificationPreferencesStore {
  SharedPreferencesNotificationStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _enabled = 'zar.notifications.enabled';
  static const _soundEnabled = 'zar.notifications.soundEnabled';
  static const _vibrationEnabled = 'zar.notifications.vibrationEnabled';
  static const _soundProfile = 'zar.notifications.soundProfile';
  static const _privacy = 'zar.notifications.privacy';
  static const _defaultReminder = 'zar.notifications.defaultReminderMinutes';
  static const _defaultSnooze = 'zar.notifications.defaultSnoozeMinutes';

  final SharedPreferencesAsync _preferences;

  @override
  Future<ZarNotificationPreferences> load() async {
    final soundName = await _preferences.getString(_soundProfile);
    final privacyName = await _preferences.getString(_privacy);

    return ZarNotificationPreferences(
      enabled: await _preferences.getBool(_enabled) ?? true,
      soundEnabled: await _preferences.getBool(_soundEnabled) ?? true,
      vibrationEnabled: await _preferences.getBool(_vibrationEnabled) ?? true,
      soundProfile: _enumByName(
        NotificationSoundProfile.values,
        soundName,
        NotificationSoundProfile.systemDefault,
      ),
      privacy: _enumByName(
        NotificationPrivacy.values,
        privacyName,
        NotificationPrivacy.limited,
      ),
      defaultReminderMinutes:
          await _preferences.getInt(_defaultReminder) ?? 60,
      defaultSnoozeMinutes: await _preferences.getInt(_defaultSnooze) ?? 30,
    );
  }

  @override
  Future<void> save(ZarNotificationPreferences value) async {
    await Future.wait([
      _preferences.setBool(_enabled, value.enabled),
      _preferences.setBool(_soundEnabled, value.soundEnabled),
      _preferences.setBool(_vibrationEnabled, value.vibrationEnabled),
      _preferences.setString(_soundProfile, value.soundProfile.name),
      _preferences.setString(_privacy, value.privacy.name),
      _preferences.setInt(_defaultReminder, value.defaultReminderMinutes),
      _preferences.setInt(_defaultSnooze, value.defaultSnoozeMinutes),
    ]);
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

class InMemoryNotificationPreferencesStore
    implements ZarNotificationPreferencesStore {
  InMemoryNotificationPreferencesStore([
    this.value = const ZarNotificationPreferences(),
  ]);

  ZarNotificationPreferences value;

  @override
  Future<ZarNotificationPreferences> load() async => value;

  @override
  Future<void> save(ZarNotificationPreferences next) async {
    value = next;
  }
}
