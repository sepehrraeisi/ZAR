import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/settlements/repository_settlement_action_sheet.dart';

void main() {
  AppRecord settlement(SettlementStatus status) => AppRecord(
    id: 'settlement',
    type: RecordType.settlement,
    operationLabel: 'دریافت',
    personId: 'person',
    amountDisplay: '۱۲٫۵',
    assetLabel: 'گرم طلا',
    date: Jalali(1405, 6, 6),
    time: const TimeOfDay(hour: 11, minute: 30),
    status: status,
  );

  Widget settlementSheet(AppRecord record) => MaterialApp(
    home: Scaffold(
      body: RepositorySettlementActionSheet(
        record: record,
        personName: 'رضا محمدی',
        reminderSummary: '۱ ساعت قبل',
        onComplete: () {},
        onEdit: () {},
        onReschedule: () {},
        onEditReminders: () {},
        onSnooze: () {},
        onCancel: () {},
      ),
    ),
  );

  testWidgets('closed settlement detail is read-only', (tester) async {
    await tester.pumpWidget(
      settlementSheet(settlement(SettlementStatus.completed)),
    );

    expect(find.text('انجام شد'), findsOneWidget);
    expect(
      find.text(
        'این تسویه بسته شده و فقط برای مشاهده در سوابق نمایش داده می‌شود.',
      ),
      findsOneWidget,
    );
    expect(find.text('زمان‌بندی مجدد'), findsNothing);
    expect(find.text('مدیریت یادآوری‌ها'), findsNothing);
    expect(find.text('یادآوری بعداً'), findsNothing);
    expect(find.text('لغو'), findsNothing);
  });

  testWidgets('open settlement retains lifecycle actions', (tester) async {
    await tester.pumpWidget(settlementSheet(settlement(SettlementStatus.open)));

    expect(find.text('در انتظار'), findsOneWidget);
    expect(find.text('انجام شد'), findsOneWidget);
    expect(find.text('زمان‌بندی مجدد'), findsOneWidget);
    expect(find.text('مدیریت یادآوری‌ها'), findsOneWidget);
    expect(find.text('یادآوری بعداً'), findsOneWidget);
    expect(find.text('لغو'), findsOneWidget);
  });

  testWidgets(
    'deal detail remains status-free and shows transaction metadata',
    (tester) async {
      final deal = AppRecord(
        id: 'deal',
        type: RecordType.deal,
        operationLabel: 'خرید',
        personId: 'person',
        amountDisplay: r'$1,250.25',
        assetLabel: 'ارز',
        currencyCode: 'USD',
        date: Jalali(1405, 6, 7),
        time: const TimeOfDay(hour: 9, minute: 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DealDetailSheet(
              record: deal,
              personName: 'علی رضایی',
              linkedSettlements: const [],
              onOpenSettlement: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('جزئیات معامله (خرید)'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('در انتظار'), findsNothing);
      expect(find.text('انجام شد'), findsNothing);
      expect(find.text('لغو شد'), findsNothing);
    },
  );
}
