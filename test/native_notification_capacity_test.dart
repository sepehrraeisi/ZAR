import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/reminders/native_notification_capacity.dart';

void main() {
  test('keeps only the earliest reminders within the iOS safety limit', () {
    final now = DateTime.now();
    const policy = NativeNotificationCapacityPolicy(iosPendingLimit: 3);

    final selected = policy.earliestForIos([
      NativeReminderCandidate(value: 'late', fireAt: now.add(const Duration(hours: 5))),
      NativeReminderCandidate(value: 'first', fireAt: now.add(const Duration(hours: 1))),
      NativeReminderCandidate(value: 'third', fireAt: now.add(const Duration(hours: 3))),
      NativeReminderCandidate(value: 'second', fireAt: now.add(const Duration(hours: 2))),
      NativeReminderCandidate(value: 'fourth', fireAt: now.add(const Duration(hours: 4))),
    ]);

    expect(selected.map((e) => e.value), ['first', 'second', 'third']);
  });

  test('drops already expired reminders before applying capacity', () {
    final now = DateTime.now();
    const policy = NativeNotificationCapacityPolicy(iosPendingLimit: 2);

    final selected = policy.earliestForIos([
      NativeReminderCandidate(value: 'expired', fireAt: now.subtract(const Duration(minutes: 1))),
      NativeReminderCandidate(value: 'one', fireAt: now.add(const Duration(minutes: 1))),
      NativeReminderCandidate(value: 'two', fireAt: now.add(const Duration(minutes: 2))),
    ]);

    expect(selected.map((e) => e.value), ['one', 'two']);
  });

  test('zero capacity schedules nothing', () {
    const policy = NativeNotificationCapacityPolicy(iosPendingLimit: 0);
    final selected = policy.earliestForIos([
      NativeReminderCandidate(value: 'x', fireAt: DateTime.now().add(const Duration(hours: 1))),
    ]);
    expect(selected, isEmpty);
  });
}
