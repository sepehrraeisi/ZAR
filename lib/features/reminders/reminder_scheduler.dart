import 'reminder_model.dart';

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.recordId,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final String id;
  final String recordId;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

/// Platform-neutral boundary for native reminder delivery.
///
/// The current Phase A2 implementation intentionally uses an in-memory
/// implementation. A later iOS/Android adapter can use flutter_local_notifications
/// (and later FCM/APNs for multi-device delivery) without changing business logic.
abstract interface class ReminderScheduler {
  Future<void> replaceForRecord({
    required String recordId,
    required DateTime dueAt,
    required ReminderPlan plan,
    required String title,
    required String body,
  });

  Future<void> cancelForRecord(String recordId);

  Future<List<ScheduledReminder>> pendingForRecord(String recordId);
}

class InMemoryReminderScheduler implements ReminderScheduler {
  final Map<String, List<ScheduledReminder>> _byRecord = {};

  @override
  Future<void> replaceForRecord({
    required String recordId,
    required DateTime dueAt,
    required ReminderPlan plan,
    required String title,
    required String body,
  }) async {
    final scheduled = <ScheduledReminder>[];
    var index = 0;
    for (final time in plan.resolveTimes(dueAt)) {
      scheduled.add(
        ScheduledReminder(
          id: '$recordId-${index++}-${time.millisecondsSinceEpoch}',
          recordId: recordId,
          scheduledAt: time,
          title: title,
          body: body,
        ),
      );
    }
    _byRecord[recordId] = scheduled;
  }

  @override
  Future<void> cancelForRecord(String recordId) async {
    _byRecord.remove(recordId);
  }

  @override
  Future<List<ScheduledReminder>> pendingForRecord(String recordId) async =>
      List.unmodifiable(_byRecord[recordId] ?? const []);
}
