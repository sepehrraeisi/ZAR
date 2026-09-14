import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/settlements/operational_pending_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  testWidgets('pending screen renders compact consistent cards', (
    tester,
  ) async {
    final records = [
      AppRecord(
        id: 'usd',
        type: RecordType.settlement,
        operationLabel: 'دریافت',
        personId: 'p1',
        amountDisplay: r'$6,000.50',
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
    expect(find.text('USD ۶٬۰۰۰٫۵۰'), findsOneWidget);
    expect(find.text('گرم طلا ۵٬۰۰۰ • عیار ۷۵۰'), findsOneWidget);
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

  testWidgets(
    'receive and pay rows keep a physical left chevron while app bar back stays right',
    (tester) async {
      Future<void> openPending(String title) async {
        final record = AppRecord(
          id: title,
          type: RecordType.settlement,
          operationLabel: title == 'در انتظار دریافت' ? 'دریافت' : 'تحویل',
          personId: 'p1',
          amountDisplay: '۱۰۰',
          assetLabel: 'وجه نقد',
          currencyCode: 'TOMAN',
          date: Jalali(1405, 6, 11),
          time: const TimeOfDay(hour: 10, minute: 15),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const ValueKey('open-pending'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: OperationalPendingScreen(
                              title: title,
                              records: [record],
                              personName: (_) => 'مهیار',
                              onOpenRecord: (_) {},
                            ),
                          ),
                        ),
                      ),
                      child: const Text('باز کردن'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-pending')));
        await tester.pumpAndSettle();

        final card = tester.getRect(find.byType(Card));
        final target = tester.getRect(
          find.byKey(ValueKey('pending-chevron-target-$title')),
        );
        final icon = tester.widget<Icon>(
          find.byKey(ValueKey('pending-chevron-$title')),
        );
        expect(target.width, greaterThanOrEqualTo(44));
        expect(target.left, lessThan(card.left + 24));
        expect(icon.icon, Icons.chevron_left);
        expect(
          Directionality.of(
            tester.element(find.byKey(ValueKey('pending-chevron-$title'))),
          ),
          TextDirection.ltr,
        );

        final back = tester.getRect(find.byType(BackButton));
        expect(back.center.dx, greaterThan(360));
        expect(tester.takeException(), isNull);
      }

      await openPending('در انتظار دریافت');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openPending('در انتظار پرداخت');
    },
  );
}
