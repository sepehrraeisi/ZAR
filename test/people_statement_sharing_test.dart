import 'package:flutter_app/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  final person = AppPerson(id: 'p1', name: 'سهیل', phone: '۰۹۱۲۱۲۳۴۵۶۷');
  final balance = ZarCustomerOperationalBalance(
    const [],
    receivableAssetBuckets: const [
      ZarCustomerBalanceAssetBucket(
        direction: ZarSettlementDirection.receive,
        assetType: ZarAssetType.currency,
        currencyCode: 'USD',
        amount: '10000',
      ),
      ZarCustomerBalanceAssetBucket(
        direction: ZarSettlementDirection.receive,
        assetType: ZarAssetType.gold,
        goldFineness: '750',
        amount: '100',
      ),
    ],
    payableAssetBuckets: const [
      ZarCustomerBalanceAssetBucket(
        direction: ZarSettlementDirection.deliver,
        assetType: ZarAssetType.currency,
        currencyCode: 'EUR',
        amount: '45000',
      ),
    ],
  );
  final record = AppRecord(
    id: 'd1',
    type: RecordType.deal,
    operationLabel: 'خرید',
    personId: person.id,
    amountDisplay: '۵٬۰۰۰',
    assetLabel: 'ارز',
    currencyCode: 'USD',
    date: Jalali(1405, 6, 11),
    time: const TimeOfDay(hour: 16, minute: 42),
  );

  test('person balance share text keeps assets separate', () {
    final text = personBalanceShareText(
      person: person,
      balance: balance,
      generatedAt: DateTime(2026, 9, 11, 16, 50),
    );
    expect(text, contains('وضعیت حساب با سهیل'));
    expect(text, contains('۱۰٬۰۰۰ USD'));
    expect(text, contains('طلای عیار ۷۵۰'));
    expect(text, contains('۴۵٬۰۰۰ EUR'));
    expect(text, contains('۲۰ شهریور ۱۴۰۵'));
  });

  test('specific bucket share is an account summary, not a receipt', () {
    final text = balanceBucketShareText(
      person: person,
      bucket: balance.payableAssetBuckets.single,
      generatedAt: DateTime(2026, 9, 11, 16, 50),
    );
    expect(text, contains('باید به سهیل پرداخت کنم'));
    expect(text, contains('۴۵٬۰۰۰ EUR'));
    expect(text, contains('نه رسید معامله'));
  });

  test(
    'full statement includes open/history semantics without internal ids',
    () {
      final text = personStatementShareText(
        person: person,
        balance: balance,
        records: [record],
        generatedAt: DateTime(2026, 9, 11, 16, 50),
      );
      expect(text, contains('صورتحساب سهیل'));
      expect(text, contains('سوابق'));
      expect(text, contains('خرید'));
      expect(text, isNot(contains('d1')));
    },
  );

  testWidgets(
    'person detail exposes statement, quick entry and bucket share actions',
    (tester) async {
      var shared = false;
      var quickAdded = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa', 'IR'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PersonDetailScreen(
              person: person,
              records: const [],
              personName: (_) => 'سهیل',
              balance: balance,
              onTapRecord: (_) {},
              onEditPerson: (_) {},
              onArchivePerson: (_) {},
              onShareStatement: () => shared = true,
              onQuickEntry: () => quickAdded = true,
              onShareBalanceBucket: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اشتراک صورتحساب'), findsOneWidget);
      expect(find.text('ثبت جدید'), findsOneWidget);
      expect(find.byTooltip('اشتراک‌گذاری این مورد'), findsWidgets);
      await tester.tap(find.text('اشتراک صورتحساب'));
      await tester.tap(find.text('ثبت جدید'));
      expect(shared, isTrue);
      expect(quickAdded, isTrue);
    },
  );
}
