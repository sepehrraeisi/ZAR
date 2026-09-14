import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/history/operational_history_screen.dart';

void main() {
  final people = [
    AppPerson(id: 'p1', name: 'مهیار', phone: '09120000000'),
    AppPerson(id: 'p2', name: 'سهیل', phone: '09121111111'),
  ];

  AppRecord deal({
    String id = 'deal',
    String personId = 'p1',
    Jalali? date,
    TimeOfDay? time = const TimeOfDay(hour: 10, minute: 15),
    String amount = '۱۲٬۵۰۰',
    String asset = 'ارز',
    String? currency = 'USD',
    String? note,
  }) => AppRecord(
    id: id,
    type: RecordType.deal,
    operationLabel: 'خرید',
    personId: personId,
    amountDisplay: amount,
    assetLabel: asset,
    currencyCode: currency,
    date: date ?? Jalali(1405, 6, 20),
    time: time,
    note: note,
  );

  AppRecord settlement({
    required String id,
    String operation = 'دریافت',
    String personId = 'p1',
    SettlementStatus status = SettlementStatus.open,
    Jalali? date,
    TimeOfDay? time = const TimeOfDay(hour: 11, minute: 30),
    String asset = 'وجه نقد',
    String? currency = 'TOMAN',
    String amount = '۵۰۰٬۰۰۰',
  }) => AppRecord(
    id: id,
    type: RecordType.settlement,
    operationLabel: operation,
    personId: personId,
    amountDisplay: amount,
    assetLabel: asset,
    currencyCode: currency,
    date: date ?? Jalali(1405, 6, 21),
    time: time,
    status: status,
  );

  String nameFor(String id) =>
      people.firstWhere((person) => person.id == id).name;

  test(
    'history projection composes search, operation, status, person and asset filters',
    () {
      final records = [
        deal(
          id: 'gold',
          asset: 'گرم طلا',
          currency: null,
          amount: '۲۸',
          note: 'تست',
        ),
        deal(id: 'currency', personId: 'p2'),
        settlement(id: 'done', status: SettlementStatus.completed),
        settlement(
          id: 'cancelled',
          status: SettlementStatus.cancelled,
          operation: 'تحویل',
        ),
        settlement(id: 'pending', date: Jalali(1405, 6, 30)),
        settlement(id: 'open', date: Jalali(1405, 6, 20)),
      ];
      final now = Jalali(1405, 6, 23).toGregorian();
      final filtered = filterOperationalHistoryRecords(
        records: records,
        personName: nameFor,
        people: people,
        query: 'سهیل',
        operation: HistoryFilter.buy,
        advanced: HistoryAdvancedFilters(asset: HistoryAssetFilter.currency),
        now: DateTime(now.year, now.month, now.day, 12),
      );
      expect(filtered.map((item) => item.id), ['currency']);

      final completed = filterOperationalHistoryRecords(
        records: records,
        personName: nameFor,
        advanced: HistoryAdvancedFilters(status: HistoryStatusFilter.completed),
      );
      expect(completed.map((item) => item.id), ['done']);

      final pending = filterOperationalHistoryRecords(
        records: records,
        personName: nameFor,
        advanced: const HistoryAdvancedFilters(
          status: HistoryStatusFilter.pending,
        ),
        now: DateTime(2026, 9, 14, 12),
      );
      expect(pending.map((item) => item.id), ['pending']);

      final overdue = filterOperationalHistoryRecords(
        records: records,
        personName: nameFor,
        advanced: const HistoryAdvancedFilters(
          status: HistoryStatusFilter.overdue,
        ),
        now: DateTime(2026, 9, 14, 12),
      );
      expect(overdue.map((item) => item.id), ['open']);

      final dateRange = filterOperationalHistoryRecords(
        records: records,
        personName: nameFor,
        advanced: HistoryAdvancedFilters(
          from: Jalali(1405, 6, 21),
          to: Jalali(1405, 6, 21),
        ),
      );
      expect(dateRange.map((item) => item.id), ['done', 'cancelled']);
    },
  );

  test(
    'history projection keeps newest-first and deterministic equal-time order',
    () {
      final sameTime = [
        deal(id: 'a', date: Jalali(1405, 6, 22)),
        deal(id: 'c', date: Jalali(1405, 6, 22)),
        deal(id: 'b', date: Jalali(1405, 6, 23)),
      ];
      final result = filterOperationalHistoryRecords(
        records: sameTime,
        personName: nameFor,
      );
      expect(result.map((item) => item.id), ['b', 'c', 'a']);
      final legacy = filterOperationalHistoryRecords(
        records: [deal(id: 'legacy', time: null)],
        personName: nameFor,
      );
      expect(legacy.single.timeLabel(), 'بدون ساعت');
    },
  );

  testWidgets(
    'history keeps operation filters visible and cards physically RTL aligned',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = [
        deal(id: 'deal', amount: '۱۲٬۵۰۰'),
        settlement(id: 'done', status: SettlementStatus.completed),
        settlement(
          id: 'open',
          operation: 'تحویل',
          status: SettlementStatus.open,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: OperationalHistoryScreen(
            records: records,
            people: people,
            personName: nameFor,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('history-result-count')),
        findsOneWidget,
      );
      expect(find.text('۱۲٬۵۰۰ USD'), findsOneWidget);
      final filterViewport = tester.getRect(
        find.byKey(const ValueKey('history-operation-filters')),
      );
      final firstChip = tester.getRect(
        find.byKey(const ValueKey('history-operation-all')),
      );
      expect(firstChip.left, greaterThanOrEqualTo(filterViewport.left));
      final lastChipFinder = find.byKey(
        const ValueKey('history-operation-deliver'),
      );
      await tester.drag(
        find.byKey(const ValueKey('history-operation-filters')),
        const Offset(260, 0),
      );
      await tester.pumpAndSettle();
      final lastChip = tester.getRect(lastChipFinder);
      expect(lastChip.left, greaterThanOrEqualTo(filterViewport.left));
      expect(lastChip.right, lessThanOrEqualTo(filterViewport.right));
      await tester.drag(
        find.byKey(const ValueKey('history-operation-filters')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byKey(const ValueKey('history-record-deal')),
      );
      final main = tester.getRect(
        find.byKey(const ValueKey('history-main-deal')),
      );
      final chevron = tester.getRect(
        find.byKey(const ValueKey('history-chevron-deal')),
      );
      expect(card.width, greaterThan(300));
      expect(main.right, greaterThan(card.right - 24));
      expect(chevron.left, lessThan(card.left + 20));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('history-operation-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-record-deal')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-record-done')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('history-operation-all')));
      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        'سهیل',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-record-done')), findsNothing);
      expect(find.byKey(const ValueKey('history-record-deal')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('history-search-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-record-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-record-open')), findsOneWidget);
    },
  );

  testWidgets(
    'history card note is one line and updates when source records refresh',
    (tester) async {
      final initial = deal(
        id: 'refresh',
        note: 'یادداشت طولانی برای بررسی نمایش',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OperationalHistoryScreen(
            records: [initial],
            personName: nameFor,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('یادداشت طولانی'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: OperationalHistoryScreen(
            records: [
              initial,
              deal(id: 'newer', date: Jalali(1405, 6, 24)),
            ],
            personName: nameFor,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('history-record-newer')),
        findsOneWidget,
      );
      expect(find.text('۲ مورد'), findsOneWidget);
    },
  );

  testWidgets(
    'Deal detail uses summary-first design and keeps share available',
    (tester) async {
      final record = deal(amount: 'USD 1250.25');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryDealDetailSheet(
              record: record,
              personName: 'مهیار',
              linkedSettlements: const [],
              onOpenSettlement: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deal-detail-summary')), findsOneWidget);
      expect(find.text('۱٬۲۵۰٫۲۵ USD'), findsOneWidget);
      expect(find.byTooltip('اشتراک‌گذاری'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('۱٬۲۵۰٫۲۵ USD')).dy,
        lessThan(tester.getTopLeft(find.text('اطلاعات معامله')).dy),
      );
    },
  );
}
