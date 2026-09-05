import '../app_core.dart';
import '../domain/zar_reminder_plan.dart';
import '../features/reminders/record_reminder_registry.dart';
import '../features/reminders/reminder_model.dart';
import 'zar_phase_a2_store.dart';

/// Keeps reminder business intent and native delivery in the correct order:
/// persist first, then reconcile device notifications.
///
/// This avoids the dangerous state where a notification is changed locally but
/// the user's reminder intent is not recoverable after restart/device loss.
class PersistedReminderCoordinator {
  PersistedReminderCoordinator({
    required ZarPhaseA2Store store,
    required RecordReminderRegistry registry,
    required String Function(String personId) personName,
  })  : _store = store,
        _registry = registry,
        _personName = personName;

  final ZarPhaseA2Store _store;
  final RecordReminderRegistry _registry;
  final String Function(String personId) _personName;

  Future<void> reconcileRecord(AppRecord record) async {
    if (record.type != RecordType.settlement) return;
    final runtimePlan = reminderPlanFromDomain(_store.reminderPlanFor(record.id));
    await _registry.setPlan(
      record: record,
      plan: runtimePlan,
      personName: _personName(record.personId),
    );
  }

  Future<void> reconcileAll(Iterable<AppRecord> records) async {
    for (final record in records) {
      if (record.type == RecordType.settlement) {
        await reconcileRecord(record);
      }
    }
  }

  Future<void> reconcileAfterReplacement(Iterable<AppRecord> records) async {
    await _registry.clearTracked();
    await reconcileAll(records);
  }

  Future<void> savePlan({
    required AppRecord record,
    required ZarReminderPlan plan,
    String auditAction = 'reminder_update',
  }) async {
    if (record.type != RecordType.settlement) {
      throw ArgumentError('Reminder plans belong to settlements, not deals.');
    }
    await _store.saveReminderPlan(
      record.id,
      plan,
      auditAction: auditAction,
    );
    await reconcileRecord(record);
  }

  Future<void> snooze({
    required AppRecord record,
    required DateTime until,
  }) async {
    final plan = _store
        .reminderPlanFor(record.id)
        .copyWith(snoozedUntil: until.toUtc());
    await savePlan(record: record, plan: plan, auditAction: 'snooze');
  }

  Future<void> clearSnooze(AppRecord record) async {
    final plan = _store.reminderPlanFor(record.id).copyWith(clearSnooze: true);
    await savePlan(
      record: record,
      plan: plan,
      auditAction: 'reminder_clear_snooze',
    );
  }

  Future<void> clearAll(AppRecord record) async {
    await savePlan(
      record: record,
      plan: const ZarReminderPlan(),
      auditAction: 'reminder_clear_all',
    );
  }
}
