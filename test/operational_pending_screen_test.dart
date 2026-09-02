import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/settlements/operational_pending_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  testWidgets('pending screen renders compact consistent cards', (tester) async {
    final records = [
      AppRecord(
        id: 'usd',
        type: RecordType.settlement,
        operationLabel: 'دریافت',
        personId: 'p1',
        amountDisplay: r'$۶٬۰۰۰',
        assetLabel: 'ارز',
        currencyCode: 'USD',
        date: Jalali(1405, 6, 11),
        time: const TimeOfDay(hour: 19, minute: 56),
      ),
      AppRecord(
        id: 'gold',
        type: RecordType.settlement,
        operationLabel: 'تحویل',
        personId: 'p2',
        amountDisplay: '۵۰۰۰',
        assetLabel: 'گرم طلا',
        goldFineness: '750',
        date: Jalali(1405, 6, 11),
        time: const TimeOfDay(hour: 19, minute: 59),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: OperationalPendingScreen(
          title: 'عقب‌افتاده',
          records: records,
          personName: (id) => id == 'p1' ? 'سپهر' : 'روژیه',
          overdueRecordIds: const {'usd'},
          onOpenRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عقب‌افتاده'), findsNWidgets(2));
    expect(find.text('در انتظار'), findsOneWidget);
    expect(find.text('سپهر'), findsOneWidget);
    expect(find.text('روژیه'), findsOneWidget);
    expect(find.text(r'$۶٬۰۰۰'), findsOneWidget);
    expect(find.text('۵۰۰۰ گرم • عیار ۷۵۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending screen has a deliberate empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalPendingScreen(
          title: 'در انتظار دریافت',
          records: const [],
          personName: (_) => '',
          onOpenRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعهد بازی وجود ندارد.'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
