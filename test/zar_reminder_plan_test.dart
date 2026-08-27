import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/domain/zar_reminder_plan.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';

void main() {
  test('domain reminder plan round-trips offsets custom time and snooze', () {
    final source = ZarReminderPlan(
      rules: [
        const ZarReminderRule.offset(id: '30m', minutesBefore: 30),
        ZarReminderRule.custom(
          id: 'custom',
          customAt: DateTime.utc(2026, 9, 1, 7, 30),
        ),
      ],
      snoozedUntil: DateTime.utc(2026, 9, 1, 8, 45),
    );

    final decoded = ZarReminderPlan.fromMap(source.toMap());

    expect(decoded.rules, hasLength(2));
    expect(decoded.rules.first.minutesBefore, 30);
    expect(decoded.rules.last.customAt, DateTime.utc(2026, 9, 1, 7, 30));
    expect(decoded.snoozedUntil, DateTime.utc(2026, 9, 1, 8, 45));
  });

  test('runtime/domain adapters preserve reminder intent', () {
    final runtime = ReminderPlan(
      rules: [
        const ReminderRule.offset(id: '60m', minutesBefore: 60),
        ReminderRule.custom(
          id: 'custom',
          customAt: DateTime(2026, 9, 2, 10, 15),
        ),
      ],
      snoozedUntil: DateTime(2026, 9, 2, 11),
    );

    final domain = reminderPlanToDomain(runtime);
    final restored = reminderPlanFromDomain(domain);

    expect(restored.rules.first.minutesBefore, 60);
    expect(restored.rules.last.customAt, runtime.rules.last.customAt);
    expect(restored.snoozedUntil, runtime.snoozedUntil);
  });

  test('resolveTimes deduplicates and sorts reminder times', () {
    final due = DateTime.utc(2026, 9, 3, 12);
    final plan = ZarReminderPlan(
      rules: const [
        ZarReminderRule.offset(id: 'one-hour', minutesBefore: 60),
        ZarReminderRule.offset(id: 'duplicate', minutesBefore: 60),
        ZarReminderRule.offset(id: 'half-hour', minutesBefore: 30),
      ],
    );

    expect(plan.resolveTimes(due), [
      DateTime.utc(2026, 9, 3, 11),
      DateTime.utc(2026, 9, 3, 11, 30),
    ]);
  });
}
