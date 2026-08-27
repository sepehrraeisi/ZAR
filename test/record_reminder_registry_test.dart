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
      time: const TimeOfDay(hour: 11, minute: 0),
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
      time: const TimeOfDay(hour: 11, minute: 0),
    );
    const plan = ReminderPlan(
      rules: [ReminderRule.offset(id: 'r1', minutesBefore: 30)],
    );

    await registry.setPlan(record: original, plan: plan, personName: 'علی رضایی');
    final before = (await scheduler.pendingForRecord(original.id)).single.scheduledAt;

    final moved = original.copyWith(
      date: Jalali(1405, 6, 6),
      time: const TimeOfDay(hour: 15, minute: 0),
    );
    await registry.onRecordChanged(record: moved, personName: 'علی رضایی');
    final after = (await scheduler.pendingForRecord(original.id)).single.scheduledAt;

    expect(after, isNot(before));
    expect(after.hour, 14);
    expect(after.minute, 30);
  });

  test('uses injected notification content policy', () async {
    final scheduler = InMemoryReminderScheduler();
    final registry = RecordReminderRegistry(
      scheduler: scheduler,
      contentBuilder: (_, __) => const ReminderNotificationContent(
        title: 'یادآوری ZAR+',
        body: 'یک یادآوری کاری دارید.',
      ),
    );
    final record = AppRecord(
      id: 's3',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$25,000',
      assetLabel: 'ارز',
      date: Jalali(1405, 6, 7),
      time: const TimeOfDay(hour: 12, minute: 0),
    );

    await registry.setPlan(
      record: record,
      plan: const ReminderPlan(
        rules: [ReminderRule.offset(id: 'r1', minutesBefore: 60)],
      ),
      personName: 'رضا محمدی',
    );

    final scheduled = (await scheduler.pendingForRecord(record.id)).single;
    expect(scheduled.title, 'یادآوری ZAR+');
    expect(scheduled.body, 'یک یادآوری کاری دارید.');
    expect(scheduled.title, isNot(contains('رضا محمدی')));
    expect(scheduled.body, isNot(contains(r'$25,000')));
  });

  test('refresh rewrites already pending notification content', () async {
    final scheduler = InMemoryReminderScheduler();
    var privateMode = false;
    final registry = RecordReminderRegistry(
      scheduler: scheduler,
      contentBuilder: (record, personName) => privateMode
          ? const ReminderNotificationContent(
              title: 'یادآوری ZAR+',
              body: 'یک یادآوری کاری دارید.',
            )
          : ReminderNotificationContent(
              title: '${record.operationLabel} • $personName',
              body: '${record.assetLabel} • ${record.amountDisplay}',
            ),
    );
    final record = AppRecord(
      id: 'privacy-refresh',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$40,000',
      assetLabel: 'ارز',
      date: Jalali(1405, 6, 8),
      time: const TimeOfDay(hour: 12, minute: 0),
    );

    await registry.setPlan(
      record: record,
      plan: const ReminderPlan(
        rules: [ReminderRule.offset(id: 'r1', minutesBefore: 30)],
      ),
      personName: 'رضا محمدی',
    );
    expect(
      (await scheduler.pendingForRecord(record.id)).single.body,
      contains(r'$40,000'),
    );

    privateMode = true;
    await RecordReminderRegistry.refreshAllScheduledContent();

    final refreshed = (await scheduler.pendingForRecord(record.id)).single;
    expect(refreshed.title, 'یادآوری ZAR+');
    expect(refreshed.body, 'یک یادآوری کاری دارید.');
  });
}
