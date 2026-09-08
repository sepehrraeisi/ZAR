import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';

void main() {
  final records = <AppRecord>[
    AppRecord(
      id: 'deal-buy',
      type: RecordType.deal,
      operationLabel: 'خرید',
      personId: 'p1',
      amountDisplay: r'$1,250.25',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali(1405, 6, 4),
      time: const TimeOfDay(hour: 9, minute: 15),
    ),
    AppRecord(
      id: 'settlement-receive',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p2',
      amountDisplay: '۱۲٫۵',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11, minute: 30),
      status: SettlementStatus.completed,
    ),
    AppRecord(
      id: 'settlement-deliver',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: '۸',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 3),
      status: SettlementStatus.cancelled,
    ),
  ];

  String personName(String id) => id == 'p1' ? 'علی رضایی' : 'رضا محمدی';

  testWidgets('shows deals and settlements newest-first without deal status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(records: records, personName: personName),
      ),
    );

    final newest = find.byKey(
      const ValueKey('history-record-settlement-receive'),
    );
    final deal = find.byKey(const ValueKey('history-record-deal-buy'));
    final oldest = find.byKey(
      const ValueKey('history-record-settlement-deliver'),
    );

    expect(newest, findsOneWidget);
    expect(deal, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(tester.getTopLeft(newest).dy, lessThan(tester.getTopLeft(deal).dy));
    expect(tester.getTopLeft(deal).dy, lessThan(tester.getTopLeft(oldest).dy));
    expect(find.text('انجام شد'), findsOneWidget);
    expect(find.text('لغو شد'), findsOneWidget);
    expect(find.text('در انتظار'), findsNothing);
  });

  testWidgets('filters and searches across separate activity types', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(records: records, personName: personName),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'خرید'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('history-record-deal-buy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('history-record-settlement-receive')),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'همه'));
    await tester.enterText(find.byType(TextField), 'رضا محمدی');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('history-record-settlement-receive')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('history-record-deal-buy')), findsNothing);
  });

  testWidgets('routes deal and settlement taps with their original types', (
    tester,
  ) async {
    final tapped = <AppRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          records: records,
          personName: personName,
          onTapRecord: tapped.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('history-record-deal-buy')));
    await tester.tap(
      find.byKey(const ValueKey('history-record-settlement-receive')),
    );

    expect(tapped.map((record) => record.type), [
      RecordType.deal,
      RecordType.settlement,
    ]);
  });
}
