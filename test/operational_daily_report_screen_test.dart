import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/reports/operational_daily_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  testWidgets('daily report renders operational sections without financial totals', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 2, 12);
    final buy = deal('buy', ZarDealType.buy, DateTime(2026, 9, 2, 9));
    final sell = deal('sell', ZarDealType.sell, DateTime(2026, 9, 2, 11));
    final receive = settlement(
      'receive',
      ZarSettlementDirection.receive,
      scheduledAt: DateTime(2026, 9, 1, 10),
      status: ZarSettlementStatus.completed,
      completedAt: DateTime(2026, 9, 2, 13),
    );
    final due = settlement(
      'due',
      ZarSettlementDirection.deliver,
      scheduledAt: DateTime(2026, 9, 2, 15),
    );

    final records = [
      appRecord('buy', 'خرید', RecordType.deal, day),
      appRecord('sell', 'فروش', RecordType.deal, day),
      appRecord('receive', 'دریافت', RecordType.settlement, day,
          status: SettlementStatus.completed),
      appRecord('due', 'تحویل', RecordType.settlement, day),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: OperationalDailyReportScreen(
          deals: [buy, sell],
          settlements: [receive, due],
          records: records,
          personName: (_) => 'علی',
          onOpenRecord: (_) {},
          initialDay: day,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('گزارش روزانه'), findsOneWidget);
    expect(find.text('خریدها'), findsOneWidget);
    expect(find.text('فروش‌ها'), findsOneWidget);
    expect(find.text('دریافت‌های انجام‌شده'), findsOneWidget);
    expect(find.text('تعهدهای همان روز'), findsOneWidget);
    expect(find.text('سود'), findsNothing);
    expect(find.textContaining('زیان'), findsNothing);
    expect(find.text('۱'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}

final _amount = ZarCurrencyAssetAmount(
  ZarCurrencyAmount(code: 'USD', minorUnits: 1000000, minorUnitScale: 2),
);

ZarDeal deal(String id, ZarDealType type, DateTime at) => ZarDeal(
      id: id,
      businessId: 'business',
      type: type,
      personId: 'person',
      amount: _amount,
      dealAt: at,
      createdBy: 'user',
      createdAt: at,
      updatedAt: at,
    );

ZarSettlement settlement(
  String id,
  ZarSettlementDirection direction, {
  required DateTime scheduledAt,
  ZarSettlementStatus status = ZarSettlementStatus.open,
  DateTime? completedAt,
}) =>
    ZarSettlement(
      id: id,
      businessId: 'business',
      personId: 'person',
      direction: direction,
      amount: _amount,
      scheduledAt: scheduledAt,
      hasTime: true,
      status: status,
      completedAt: completedAt,
      completedBy: status == ZarSettlementStatus.completed ? 'user' : null,
      createdBy: 'user',
      createdAt: scheduledAt,
      updatedAt: completedAt ?? scheduledAt,
    );

AppRecord appRecord(
  String id,
  String operation,
  RecordType type,
  DateTime at, {
  SettlementStatus status = SettlementStatus.open,
}) =>
    AppRecord(
      id: id,
      type: type,
      operationLabel: operation,
      personId: 'person',
      amountDisplay: 'USD ۱۰٬۰۰۰',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.fromDateTime(at),
      time: TimeOfDay(hour: at.hour, minute: at.minute),
      status: status,
    );
