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

class _ReminderRecordContext {
  const _ReminderRecordContext(this.record, this.personName);

  final AppRecord record;
  final String personName;
}

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
        contentBuilder = contentBuilder ?? defaultContentBuilder ?? _defaultContent {
    _instances.add(this);
  }

  static ReminderScheduler? defaultScheduler;
  static ReminderContentBuilder? defaultContentBuilder;
  static final Set<RecordReminderRegistry> _instances = {};

  final ReminderScheduler scheduler;
  final ReminderContentBuilder contentBuilder;
  final Map<String, ReminderPlan> _plans = {};
  final Map<String, _ReminderRecordContext> _contexts = {};

  ReminderPlan planFor(String recordId) =>
      _plans[recordId] ?? const ReminderPlan();

  /// Rebuilds native/in-memory scheduled text for every active registry. This
  /// is used when a user changes lock-screen privacy so already-pending
  /// notifications are immediately rewritten rather than retaining old detail.
  static Future<void> refreshAllScheduledContent() async {
    for (final registry in List<RecordReminderRegistry>.from(_instances)) {
      await registry._refreshScheduledContent();
    }
  }

  Future<void> setPlan({
    required AppRecord record,
    required ReminderPlan plan,
    required String personName,
  }) async {
    _plans[record.id] = plan;
    _contexts[record.id] = _ReminderRecordContext(record, personName);
    if (!record.isObligation || record.status != SettlementStatus.open) {
      _contexts.remove(record.id);
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
      _contexts.remove(record.id);
      await scheduler.cancelForRecord(record.id);
      return;
    }
    _contexts[record.id] = _ReminderRecordContext(record, personName);
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
    _contexts.remove(recordId);
    await scheduler.cancelForRecord(recordId);
  }

  Future<void> _refreshScheduledContent() async {
    for (final entry in List<MapEntry<String, _ReminderRecordContext>>.from(
      _contexts.entries,
    )) {
      final plan = _plans[entry.key] ?? const ReminderPlan();
      await _schedule(
        record: entry.value.record,
        plan: plan,
        personName: entry.value.personName,
      );
    }
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
