import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/notifications/notification_center.dart';

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
}
