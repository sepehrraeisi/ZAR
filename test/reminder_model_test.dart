import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';
import 'package:flutter_app/features/reminders/reminder_scheduler.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('ReminderRule', () {
    test('offset resolves relative to due time', () {
      final due = DateTime(2026, 8, 27, 11);
      const rule = ReminderRule.offset(id: 'r1', minutesBefore: 60);
      expect(rule.resolve(due), DateTime(2026, 8, 27, 10));
    });

    test('plan deduplicates and sorts reminder times', () {
      final due = DateTime(2026, 8, 27, 11);
      const plan = ReminderPlan(
        rules: [
          ReminderRule.offset(id: 'r1', minutesBefore: 15),
          ReminderRule.offset(id: 'r2', minutesBefore: 60),
          ReminderRule.offset(id: 'r3', minutesBefore: 15),
        ],
      );
      expect(plan.resolveTimes(due), [
        DateTime(2026, 8, 27, 10),
        DateTime(2026, 8, 27, 10, 45),
      ]);
    });

    test('map serialization preserves structured values', () {
      final original = ReminderPlan(
        rules: const [ReminderRule.offset(id: 'r1', minutesBefore: 30)],
        snoozedUntil: DateTime(2026, 8, 28, 9),
      );
      final restored = ReminderPlan.fromMap(original.toMap());
      expect(restored.rules.single.minutesBefore, 30);
      expect(restored.snoozedUntil, DateTime(2026, 8, 28, 9));
    });
  });

  group('Jalali conversion', () {
    test('creates canonical local due DateTime from Jalali date', () {
      final due = dueDateTimeFromJalali(
        Jalali(1405, 6, 5),
        const TimeOfDay(hour: 14, minute: 30),
      );
      final gregorian = Jalali(1405, 6, 5).toGregorian();
      expect(due.year, gregorian.year);
      expect(due.month, gregorian.month);
      expect(due.day, gregorian.day);
      expect(due.hour, 14);
      expect(due.minute, 30);
    });
  });

  group('legacy label adapter', () {
    test('converts current Persian quick-add label into offset rule', () {
      final plan = reminderPlanFromLegacyLabel('۱ ساعت قبل');
      expect(plan.rules.single.minutesBefore, 60);
    });
  });

  group('ReminderScheduler', () {
    test('replace and cancel are record-scoped', () async {
      final scheduler = InMemoryReminderScheduler();
      await scheduler.replaceForRecord(
        recordId: 's1',
        dueAt: DateTime(2026, 8, 27, 11),
        plan: const ReminderPlan(
          rules: [ReminderRule.offset(id: 'r1', minutesBefore: 30)],
        ),
        title: 'تحویل',
        body: 'یادآوری کاری',
      );
      expect((await scheduler.pendingForRecord('s1')).single.scheduledAt,
          DateTime(2026, 8, 27, 10, 30));

      await scheduler.cancelForRecord('s1');
      expect(await scheduler.pendingForRecord('s1'), isEmpty);
    });
  });
}
