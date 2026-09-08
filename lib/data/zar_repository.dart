import '../app_core.dart';
import '../features/reminders/reminder_model.dart';

class ZarWorkspaceSnapshot {
  const ZarWorkspaceSnapshot({
    required this.people,
    required this.records,
    required this.reminders,
  });

  final List<AppPerson> people;
  final List<AppRecord> records;
  final Map<String, ReminderPlan> reminders;
}

abstract interface class ZarRepository {
  Future<ZarWorkspaceSnapshot> loadWorkspace();

  Future<void> savePerson(AppPerson person);

  Future<void> saveRecord(AppRecord record);

  Future<void> saveReminderPlan(String recordId, ReminderPlan plan);

  Future<void> appendAuditEvent({
    required String recordId,
    required String recordType,
    required String action,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  });
}

class InMemoryZarRepository implements ZarRepository {
  InMemoryZarRepository({
    Iterable<AppPerson> people = const [],
    Iterable<AppRecord> records = const [],
    Map<String, ReminderPlan> reminders = const {},
  })  : _people = {for (final person in people) person.id: person},
        _records = {for (final record in records) record.id: record},
        _reminders = Map.of(reminders);

  final Map<String, AppPerson> _people;
  final Map<String, AppRecord> _records;
  final Map<String, ReminderPlan> _reminders;
  final List<Map<String, Object?>> auditEvents = [];

  @override
  Future<ZarWorkspaceSnapshot> loadWorkspace() async => ZarWorkspaceSnapshot(
        people: _people.values.toList(growable: false),
        records: _records.values.toList(growable: false),
        reminders: Map.unmodifiable(_reminders),
      );

  @override
  Future<void> savePerson(AppPerson person) async {
    _people[person.id] = person;
  }

  @override
  Future<void> saveRecord(AppRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<void> saveReminderPlan(String recordId, ReminderPlan plan) async {
    _reminders[recordId] = plan;
  }

  @override
  Future<void> appendAuditEvent({
    required String recordId,
    required String recordType,
    required String action,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  }) async {
    auditEvents.add({
      'recordId': recordId,
      'recordType': recordType,
      'action': action,
      'before': before,
      'after': after,
    });
  }
}
