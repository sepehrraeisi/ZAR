import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/zar_repository.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('in-memory repository preserves archive and reminder data', () async {
    final repository = InMemoryZarRepository();
    final person = AppPerson(id: 'p1', name: 'علی رضایی', archived: true);
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۲۵۰',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
    );
    const plan = ReminderPlan(
      rules: [ReminderRule.offset(id: 'r1', minutesBefore: 60)],
    );

    await repository.savePerson(person);
    await repository.saveRecord(record);
    await repository.saveReminderPlan(record.id, plan);
    await repository.appendAuditEvent(
      recordId: person.id,
      recordType: 'person',
      action: 'archive',
    );

    final snapshot = await repository.loadWorkspace();
    expect(snapshot.people.single.archived, isTrue);
    expect(snapshot.records.single.id, 's1');
    expect(snapshot.reminders['s1']?.rules.single.minutesBefore, 60);
    expect(repository.auditEvents.single['action'], 'archive');
  });
}
