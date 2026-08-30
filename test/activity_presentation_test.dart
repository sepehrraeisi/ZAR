import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/main_phase_a2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('fa', 'IR'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(child: child),
      ),
    );

AppRecord _record({
  required String id,
  required RecordType type,
  required String operation,
  SettlementStatus status = SettlementStatus.open,
}) =>
    AppRecord(
      id: id,
      type: type,
      operationLabel: operation,
      personId: 'p1',
      amountDisplay: type == RecordType.deal ? r'$2,500.50' : '۲۵۰.۵',
      assetLabel: type == RecordType.deal ? 'ارز' : 'گرم طلا',
      currencyCode: type == RecordType.deal ? 'USD' : null,
      date: Jalali.now(),
      time: const TimeOfDay(hour: 16, minute: 30),
      status: status,
    );

void main() {
  testWidgets('calendar shows deals and settlements without sharing lifecycle labels',
      (tester) async {
    await tester.pumpWidget(
      _host(
        CalendarScreen(
          records: [
            _record(id: 'd1', type: RecordType.deal, operation: 'خرید'),
            _record(
              id: 's1',
              type: RecordType.settlement,
              operation: 'دریافت',
            ),
          ],
          personName: (_) => 'هما',
          onTapRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('خرید'), findsOneWidget);
    expect(find.text('دریافت'), findsOneWidget);
    expect(find.text('معامله'), findsOneWidget);
    expect(find.text('در انتظار'), findsOneWidget);
  });

  testWidgets('people summary includes deal and open obligation counts',
      (tester) async {
    await tester.pumpWidget(
      _host(
        PhaseA2PeopleScreen(
          people: [AppPerson(id: 'p1', name: 'سهیل')],
          records: [
            _record(id: 'd1', type: RecordType.deal, operation: 'فروش'),
            _record(
              id: 's1',
              type: RecordType.settlement,
              operation: 'تحویل',
            ),
          ],
          archivedCount: 0,
          onAddPerson: () {},
          onOpenPerson: (_) {},
          onOpenArchive: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('۱ معامله • ۱ تعهد باز'), findsOneWidget);
  });

  testWidgets('person detail separates open obligations from transaction history',
      (tester) async {
    await tester.pumpWidget(
      _host(
        PersonDetailScreen(
          person: AppPerson(id: 'p1', name: 'سهیل'),
          records: [
            _record(id: 'd1', type: RecordType.deal, operation: 'خرید'),
            _record(
              id: 's1',
              type: RecordType.settlement,
              operation: 'دریافت',
            ),
            _record(
              id: 's2',
              type: RecordType.settlement,
              operation: 'تحویل',
              status: SettlementStatus.completed,
            ),
          ],
          personName: (_) => 'سهیل',
          onTapRecord: (_) {},
          onEditPerson: (_) {},
          onArchivePerson: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعهدهای باز'), findsOneWidget);
    expect(find.text('سوابق معاملات و تسویه‌ها'), findsOneWidget);
    expect(find.text('خرید'), findsOneWidget);
    expect(find.text('دریافت'), findsOneWidget);
    expect(find.text('تحویل'), findsOneWidget);
    expect(find.text('در انتظار'), findsOneWidget);
    expect(find.text('انجام شد'), findsOneWidget);
  });
}
