import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/notifications/notification_center.dart';
import 'package:flutter_app/features/notifications/notification_preferences_store.dart';

void main() {
  test('notification preferences preserve sound profile and privacy', () {
    const original = ZarNotificationPreferences();
    final changed = original.copyWith(
      soundProfile: NotificationSoundProfile.subtle,
      privacy: NotificationPrivacy.private,
      defaultReminderMinutes: 30,
      defaultSnoozeMinutes: 15,
    );

    expect(changed.soundProfile, NotificationSoundProfile.subtle);
    expect(changed.privacy, NotificationPrivacy.private);
    expect(changed.defaultReminderMinutes, 30);
    expect(changed.defaultSnoozeMinutes, 15);
  });

  test('sound can be disabled without losing selected sound profile', () {
    const preferences = ZarNotificationPreferences(
      soundProfile: NotificationSoundProfile.subtle,
    );
    final muted = preferences.copyWith(soundEnabled: false);

    expect(muted.soundEnabled, isFalse);
    expect(muted.soundProfile, NotificationSoundProfile.subtle);
  });

  test('device-local preference store round-trips all notification options', () async {
    final store = InMemoryNotificationPreferencesStore();
    const expected = ZarNotificationPreferences(
      enabled: false,
      soundEnabled: false,
      vibrationEnabled: false,
      soundProfile: NotificationSoundProfile.silent,
      privacy: NotificationPrivacy.private,
      defaultReminderMinutes: 120,
      defaultSnoozeMinutes: 45,
    );

    await store.save(expected);
    final restored = await store.load();

    expect(restored.enabled, expected.enabled);
    expect(restored.soundEnabled, expected.soundEnabled);
    expect(restored.vibrationEnabled, expected.vibrationEnabled);
    expect(restored.soundProfile, expected.soundProfile);
    expect(restored.privacy, expected.privacy);
    expect(restored.defaultReminderMinutes, expected.defaultReminderMinutes);
    expect(restored.defaultSnoozeMinutes, expected.defaultSnoozeMinutes);
  });
}
