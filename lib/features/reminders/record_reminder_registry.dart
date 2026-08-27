import '../../app_core.dart';
import 'reminder_model.dart';
import 'reminder_scheduler.dart';

/// Coordinates reminder state with settlement lifecycle without coupling UI to
/// a native notification plugin. Firebase/native adapters can replace storage
/// and delivery later while preserving these semantics.
class RecordReminderRegistry {
  RecordReminderRegistry({ReminderScheduler? scheduler})
      : scheduler = scheduler ?? InMemoryReminderScheduler();

  final ReminderScheduler scheduler;
  final Map<String, ReminderPlan> _plans = {};

  ReminderPlan planFor(String recordId) => _plans[recordId] ?? const ReminderPlan();

  Future<void> setPlan({
    required AppRecord record,
    required ReminderPlan plan,
    required String personName,
  }) async {
    _plans[record.id] = plan;
    if (!record.isObligation || record.status != SettlementStatus.open) {
      await scheduler.cancelForRecord(record.id);
      return;
    }
    await _schedule(record: record, plan: plan, personName: personName);
  }

  Future<void> onRecordChanged({
    required AppRecord record,
    required String personName,
  }) async {
    final plan = planFor(record.id);
    if (!record.isObligation || record.status != SettlementStatus.open) {
      await scheduler.cancelForRecord(record.id);
      return;
    }
    await _schedule(record: record, plan: plan, personName: personName);
  }

  Future<void> snooze({
    required AppRecord record,
    required DateTime until,
    required String personName,
  }) async {
    final plan = planFor(record.id).copyWith(snoozedUntil: until);
    await setPlan(record: record, plan: plan, personName: personName);
  }

  Future<void> cancel(String recordId) async {
    _plans.remove(recordId);
    await scheduler.cancelForRecord(recordId);
  }

  Future<void> _schedule({
    required AppRecord record,
    required ReminderPlan plan,
    required String personName,
  }) async {
    final dueAt = dueDateTimeFromJalali(record.date, record.time);
    await scheduler.replaceForRecord(
      recordId: record.id,
      dueAt: dueAt,
      plan: plan,
      title: '${record.operationLabel} • $personName',
      body: '${record.assetLabel} • ${record.amountDisplay}',
    );
  }
}
