import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/zar_backup_codec.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('JSON backup roundtrip preserves people, records, archive and reminders', () {
    final bundle = ZarBackupBundle(
      generatedAt: DateTime(2026, 8, 27, 12),
      people: [
        AppPerson(
          id: 'p1',
          name: 'علی رضایی',
          phone: '۰۹۱۲۱۲۳۴۵۶۷',
          note: 'مشتری ثابت',
          archived: true,
        ),
      ],
      records: [
        AppRecord(
          id: 's1',
          type: RecordType.settlement,
          operationLabel: 'تحویل',
          personId: 'p1',
          amountDisplay: r'$10,000',
          assetLabel: 'ارز',
          currencyCode: 'USD',
          date: Jalali(1405, 6, 5),
          time: const TimeOfDay(hour: 11, minute: 30),
          status: SettlementStatus.open,
          note: 'نمونه',
        ),
      ],
      reminders: const {
        's1': ReminderPlan(
          rules: [ReminderRule.offset(id: 'r1', minutesBefore: 60)],
        ),
      },
    );

    const codec = ZarBackupCodec();
    final encoded = codec.encodeJson(bundle);
    final restored = codec.decodeJson(encoded);

    expect(restored.exportVersion, 1);
    expect(restored.people.single.name, 'علی رضایی');
    expect(restored.people.single.archived, isTrue);
    expect(restored.records.single.currencyCode, 'USD');
    expect(restored.records.single.date.year, 1405);
    expect(restored.records.single.time?.minute, 30);
    expect(restored.reminders['s1']?.rules.single.minutesBefore, 60);
  });

  test('unknown export version is rejected safely', () {
    const codec = ZarBackupCodec();
    expect(
      () => codec.decodeJson(
        '{"exportVersion":99,"generatedAt":"2026-08-27T00:00:00.000Z"}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
