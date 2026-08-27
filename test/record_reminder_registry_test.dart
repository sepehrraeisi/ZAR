import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/reminders/record_reminder_registry.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';
import 'package:flutter_app/features/reminders/reminder_scheduler.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('completing a settlement cancels scheduled reminders', () async {
    final scheduler = InMemoryReminderScheduler();
    final registry = RecordReminderRegistry(scheduler: scheduler);
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$10,000',
      assetLabel: 'ارز',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11),
    );

    await registry.setPlan(
      record: record,
      plan: const ReminderPlan(
        rules: [ReminderRule.offset(id: 'r1', minutesBefore: 60)],
      ),
      personName: 'علی رضایی',
    );
    expect(await scheduler.pendingForRecord(record.id), isNotEmpty);

    await registry.onRecordChanged(
      record: record.copyWith(status: SettlementStatus.completed),
      personName: 'علی رضایی',
    );
    expect(await scheduler.pendingForRecord(record.id), isEmpty);
  });

  test('rescheduling a settlement replaces reminder time', () async {
    final scheduler = InMemoryReminderScheduler();
    final registry = RecordReminderRegistry(scheduler: scheduler);
    final original = AppRecord(
      id: 's2',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۲۵۰',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11),
    );
    const plan = ReminderPlan(
      rules: [ReminderRule.offset(id: 'r1', minutesBefore: 30)],
    );

    await registry.setPlan(record: original, plan: plan, personName: 'علی رضایی');
    final before = (await scheduler.pendingForRecord(original.id)).single.scheduledAt;

    final moved = original.copyWith(
      date: Jalali(1405, 6, 6),
      time: const TimeOfDay(hour: 15),
    );
    await registry.onRecordChanged(record: moved, personName: 'علی رضایی');
    final after = (await scheduler.pendingForRecord(original.id)).single.scheduledAt;

    expect(after, isNot(before));
    expect(after.hour, 14);
    expect(after.minute, 30);
  });
}
