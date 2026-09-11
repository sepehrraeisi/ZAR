import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/reports/operational_daily_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  testWidgets(
    'daily report renders operational sections without financial totals',
    (tester) async {
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
        appRecord(
          'receive',
          'دریافت',
          RecordType.settlement,
          day,
          status: SettlementStatus.completed,
        ),
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
      expect(find.text('نیازمند اقدام'), findsOneWidget);
      expect(find.text('خرید و فروش'), findsOneWidget);
      expect(find.textContaining('خرید'), findsWidgets);
      expect(find.textContaining('فروش'), findsWidgets);
      expect(find.text('USD'), findsWidgets);
      expect(find.textContaining('دریافت و پرداخت'), findsWidgets);
      expect(find.textContaining('موعد این روز'), findsOneWidget);
      expect(find.text('سود'), findsNothing);
      expect(find.textContaining('زیان'), findsNothing);
      expect(find.textContaining('حرکت'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daily report highlights overdue work separately', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 2, 12);
    final overdue = settlement(
      'overdue',
      ZarSettlementDirection.receive,
      scheduledAt: DateTime(2026, 9, 1, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationalDailyReportScreen(
          deals: const [],
          settlements: [overdue],
          records: [appRecord('overdue', 'دریافت', RecordType.settlement, day)],
          personName: (_) => 'علی',
          onOpenRecord: (_) {},
          initialDay: day,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('عقب‌افتاده'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily report chevrons keep their intended RTL direction', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 2, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: OperationalDailyReportScreen(
            deals: [deal('buy', ZarDealType.buy, day)],
            settlements: const [],
            records: [appRecord('buy', 'خرید', RecordType.deal, day)],
            personName: (_) => 'علی',
            onOpenRecord: (_) {},
            initialDay: day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previous = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == Icons.chevron_right &&
          widget.textDirection == TextDirection.ltr,
    );
    final nextAndDisclosure = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == Icons.chevron_left &&
          widget.textDirection == TextDirection.ltr,
    );
    expect(previous, findsOneWidget);
    expect(nextAndDisclosure, findsNWidgets(2));
  });

  testWidgets('shows Today only for the actual local selected day', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 10, 12);
    Widget screen(DateTime day) => MaterialApp(
      home: OperationalDailyReportScreen(
        key: ValueKey(day),
        deals: const [],
        settlements: const [],
        records: const [],
        personName: (_) => 'علی',
        onOpenRecord: (_) {},
        initialDay: day,
        clock: () => now,
      ),
    );

    await tester.pumpWidget(screen(now));
    await tester.pumpAndSettle();
    expect(find.textContaining('امروز ·'), findsOneWidget);

    await tester.pumpWidget(screen(now.subtract(const Duration(days: 1))));
    await tester.pumpAndSettle();
    expect(find.textContaining('امروز ·'), findsNothing);
    expect(find.text('امروز'), findsNothing);
  });

  testWidgets(
    'refreshes from the supplied state listenable without reopening',
    (tester) async {
      final now = DateTime(2026, 9, 10, 12);
      final notifier = ValueNotifier<int>(0);
      final records = <AppRecord>[];
      final deals = <ZarDeal>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OperationalDailyReportScreen(
            deals: const [],
            settlements: const [],
            records: const [],
            dealsBuilder: () => deals,
            recordsBuilder: () => records,
            settlementsBuilder: () => const [],
            stateListenable: notifier,
            personName: (_) => 'علی',
            onOpenRecord: (_) {},
            initialDay: now,
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('خرید و فروش · ۰'), findsOneWidget);

      deals.add(deal('new-buy', ZarDealType.buy, now));
      records.add(appRecord('new-buy', 'خرید', RecordType.deal, now));
      notifier.value++;
      await tester.pumpAndSettle();
      expect(find.text('خرید و فروش · ۱'), findsOneWidget);
      expect(find.text('خرید از علی'), findsOneWidget);
    },
  );

  testWidgets('fits the report at 360dp without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime(2026, 9, 10, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalDailyReportScreen(
          deals: [deal('buy', ZarDealType.buy, now)],
          settlements: const [],
          records: [appRecord('buy', 'خرید', RecordType.deal, now)],
          personName: (_) => 'علی',
          onOpenRecord: (_) {},
          initialDay: now,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
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
}) => ZarSettlement(
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
}) => AppRecord(
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
