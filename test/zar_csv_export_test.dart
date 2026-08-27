import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/zar_csv_export.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('CSV includes Persian headers and escapes notes safely', () {
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$10,000',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11, minute: 30),
      note: 'تحویل، با یادداشت "مهم"',
    );

    const exporter = ZarCsvExport();
    final csv = exporter.encode(
      records: [record],
      personName: (_) => 'علی رضایی',
    );

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('شناسه'));
    expect(csv, contains('علی رضایی'));
    expect(csv, contains('USD'));
    expect(csv, contains('1405/06/05'));
    expect(csv, contains('""مهم""'));
  });
}
