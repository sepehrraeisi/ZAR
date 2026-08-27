import '../../app_core.dart';
import 'reminder_model.dart';
import 'reminder_scheduler.dart';

class ReminderNotificationContent {
  const ReminderNotificationContent({required this.title, required this.body});

  final String title;
  final String body;
}

typedef ReminderContentBuilder = ReminderNotificationContent Function(
  AppRecord record,
  String personName,
);

/// Coordinates reminder state with settlement lifecycle without coupling UI to
/// a native notification plugin.
///
/// Native/local delivery and lock-screen privacy policy are injected so the
/// business lifecycle stays testable and deterministic.
class RecordReminderRegistry {
  RecordReminderRegistry({
    ReminderScheduler? scheduler,
    ReminderContentBuilder? contentBuilder,
  })  : scheduler = scheduler ?? defaultScheduler ?? InMemoryReminderScheduler(),
        contentBuilder = contentBuilder ?? defaultContentBuilder ?? _defaultContent;

  /// App startup may install a native scheduler here. Unit tests and web
  /// previews intentionally leave it null and retain deterministic in-memory
  /// scheduling.
  static ReminderScheduler? defaultScheduler;

  /// App startup may install a privacy-aware content builder here. This keeps
  /// the reminder lifecycle independent from notification presentation policy.
  static ReminderContentBuilder? defaultContentBuilder;

  final ReminderScheduler scheduler;
  final ReminderContentBuilder contentBuilder;
  final Map<String, ReminderPlan> _plans = {};

  ReminderPlan planFor(String recordId) =>
      _plans[recordId] ?? const ReminderPlan();

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
    final content = contentBuilder(record, personName);
    await scheduler.replaceForRecord(
      recordId: record.id,
      dueAt: dueAt,
      plan: plan,
      title: content.title,
      body: content.body,
    );
  }

  static ReminderNotificationContent _defaultContent(
    AppRecord record,
    String personName,
  ) =>
      ReminderNotificationContent(
        title: '${record.operationLabel} • $personName',
        body: '${record.assetLabel} • ${record.amountDisplay}',
      );
}
