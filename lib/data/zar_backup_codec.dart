import 'dart:convert';

import '../app_core.dart';
import '../features/reminders/reminder_model.dart';

class ZarBackupBundle {
  const ZarBackupBundle({
    required this.generatedAt,
    required this.people,
    required this.records,
    this.reminders = const {},
    this.exportVersion = 1,
  });

  final int exportVersion;
  final DateTime generatedAt;
  final List<AppPerson> people;
  final List<AppRecord> records;
  final Map<String, ReminderPlan> reminders;
}

class ZarBackupCodec {
  const ZarBackupCodec();

  String encodeJson(ZarBackupBundle bundle) {
    final payload = <String, Object?>{
      'app': 'ZAR+',
      'exportVersion': bundle.exportVersion,
      'generatedAt': bundle.generatedAt.toUtc().toIso8601String(),
      'people': bundle.people.map(_personToMap).toList(growable: false),
      'records': bundle.records.map(_recordToMap).toList(growable: false),
      'reminders': bundle.reminders.map((id, plan) => MapEntry(id, plan.toMap())),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ZarBackupBundle decodeJson(String source) {
    final raw = jsonDecode(source) as Map<String, Object?>;
    final version = raw['exportVersion'] as int? ?? 0;
    if (version != 1) {
      throw FormatException('Unsupported ZAR+ export version: $version');
    }
    final peopleRaw = raw['people'] as List<Object?>? ?? const [];
    final recordsRaw = raw['records'] as List<Object?>? ?? const [];
    final remindersRaw = raw['reminders'] as Map<String, Object?>? ?? const {};
    return ZarBackupBundle(
      exportVersion: version,
      generatedAt: DateTime.parse(raw['generatedAt']! as String).toLocal(),
      people: peopleRaw
          .map((e) => _personFromMap(Map<String, Object?>.from(e! as Map)))
          .toList(growable: false),
      records: recordsRaw
          .map((e) => _recordFromMap(Map<String, Object?>.from(e! as Map)))
          .toList(growable: false),
      reminders: remindersRaw.map(
        (id, value) => MapEntry(
          id,
          ReminderPlan.fromMap(Map<String, Object?>.from(value! as Map)),
        ),
      ),
    );
  }

  Map<String, Object?> _personToMap(AppPerson person) => {
        'id': person.id,
        'name': person.name,
        'phone': person.phone,
        'note': person.note,
        'archived': person.archived,
      };

  AppPerson _personFromMap(Map<String, Object?> map) => AppPerson(
        id: map['id']! as String,
        name: map['name']! as String,
        phone: map['phone'] as String?,
        note: map['note'] as String?,
        archived: map['archived'] as bool? ?? false,
      );

  Map<String, Object?> _recordToMap(AppRecord record) => {
        'id': record.id,
        'type': record.type.name,
        'operationLabel': record.operationLabel,
        'personId': record.personId,
        'amountDisplay': record.amountDisplay,
        'assetLabel': record.assetLabel,
        'jalaliDate': {
          'year': record.date.year,
          'month': record.date.month,
          'day': record.date.day,
        },
        'currencyCode': record.currencyCode,
        'time': record.time == null
            ? null
            : {'hour': record.time!.hour, 'minute': record.time!.minute},
        'status': record.status.name,
        'note': record.note,
        'linkedSettlementIds': record.linkedSettlementIds,
      };

  AppRecord _recordFromMap(Map<String, Object?> map) {
    final date = Map<String, Object?>.from(map['jalaliDate']! as Map);
    final timeRaw = map['time'] == null ? null : Map<String, Object?>.from(map['time']! as Map);
    return AppRecord(
      id: map['id']! as String,
      type: RecordType.values.byName(map['type']! as String),
      operationLabel: map['operationLabel']! as String,
      personId: map['personId']! as String,
      amountDisplay: map['amountDisplay']! as String,
      assetLabel: map['assetLabel']! as String,
      date: Jalali(
        date['year']! as int,
        date['month']! as int,
        date['day']! as int,
      ),
      currencyCode: map['currencyCode'] as String?,
      time: timeRaw == null
          ? null
          : TimeOfDay(
              hour: timeRaw['hour']! as int,
              minute: timeRaw['minute']! as int,
            ),
      status: SettlementStatus.values.byName(map['status']! as String),
      note: map['note'] as String?,
      linkedSettlementIds:
          (map['linkedSettlementIds'] as List<Object?>? ?? const []).cast<String>(),
    );
  }
}
