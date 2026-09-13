import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app_core.dart';
import 'package:shamsi_date/shamsi_date.dart';

DateTime _gregorian(Jalali date, [int hour = 12, int minute = 0]) {
  final value = date.toGregorian();
  return DateTime(value.year, value.month, value.day, hour, minute);
}

AppRecord _record({
  required String id,
  required RecordType type,
  required String operation,
  required Jalali date,
  required DateTime calendarAt,
  String amount = '۶۰۰',
  String asset = 'ارز',
  String? currency = 'GBP',
  SettlementStatus status = SettlementStatus.open,
}) => AppRecord(
  id: id,
  type: type,
  operationLabel: operation,
  personId: 'p1',
  amountDisplay: amount,
  assetLabel: asset,
  currencyCode: currency,
  date: date,
  time: TimeOfDay(hour: calendarAt.hour, minute: calendarAt.minute),
  calendarAt: calendarAt,
  status: status,
);

Widget _host(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Material(child: child),
  ),
);

void main() {
  testWidgets('calendar uses semantic timestamps and stable agenda hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = Jalali.now();
    final yesterday = today.addDays(-1);
    await tester.pumpWidget(
      _host(
        CalendarScreen(
          clock: () => _gregorian(today, 18, 0),
          records: [
            _record(
              id: 'deal',
              type: RecordType.deal,
              operation: 'خرید',
              date: today,
              calendarAt: _gregorian(today, 16, 30),
              amount: '۲۵۰',
              asset: 'گرم طلا',
              currency: null,
            ),
            _record(
              id: 'pending',
              type: RecordType.settlement,
              operation: 'دریافت',
              date: yesterday,
              calendarAt: _gregorian(today, 17, 0),
              status: SettlementStatus.open,
            ),
            _record(
              id: 'completed',
              type: RecordType.settlement,
              operation: 'تحویل',
              date: yesterday,
              calendarAt: _gregorian(today, 15, 0),
              status: SettlementStatus.completed,
            ),
          ],
          personName: (_) => 'هما',
          onTapRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.textContaining('فعالیت‌های'), findsOneWidget);
    expect(find.text('خرید'), findsOneWidget);
    expect(find.text('دریافت'), findsOneWidget);
    expect(find.text('پرداخت'), findsOneWidget);
    expect(find.text('ثبت شده'), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsOneWidget);
    expect(find.text('انجام شد'), findsOneWidget);
    expect(find.text('معامله'), findsNothing);
    expect(find.text('GBP'), findsNWidgets(2));
    expect(find.text('۶۰۰'), findsNWidgets(2));
    expect(find.text('گرم طلا'), findsOneWidget);
    expect(find.text('۲۵۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty selected day has a quiet actionable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CalendarScreen(
          records: const [],
          personName: (_) => '',
          onTapRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('برای این روز فعالیتی ثبت نشده'), findsNWidgets(2));
    expect(find.text('ثبت جدید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('month navigation follows physical left/right semantics', (
    tester,
  ) async {
    final current = Jalali.now().withDay(1);
    await tester.pumpWidget(
      _host(
        CalendarScreen(
          records: const [],
          personName: (_) => '',
          onTapRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(monthName(current.month)), findsWidgets);

    await tester.tap(find.byTooltip('ماه بعد'));
    await tester.pumpAndSettle();
    final next = current.addMonths(1);
    expect(
      find.text(
        '${monthName(next.month)} ${toPersianDigits(next.year.toString())}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('ماه قبل'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${monthName(current.month)} ${toPersianDigits(current.year.toString())}',
      ),
      findsOneWidget,
    );
  });
}
