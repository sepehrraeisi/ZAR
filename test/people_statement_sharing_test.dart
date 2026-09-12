import 'package:flutter_app/app_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/application/customer_position_projector.dart';
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
    expect(text, contains('USD ۱۰٬۰۰۰'));
    expect(text, contains('گرم طلا ۱۰۰ — عیار ۷۵۰'));
    expect(text, contains('EUR ۴۵٬۰۰۰'));
    expect(text, contains('۲۰ شهریور ۱۴۰۵'));
  });

  test('specific bucket share is an account summary, not a receipt', () {
    final text = balanceBucketShareText(
      person: person,
      bucket: balance.payableAssetBuckets.single,
      generatedAt: DateTime(2026, 9, 11, 16, 50),
    );
    expect(text, contains('باید به سهیل پرداخت کنم'));
    expect(text, contains('EUR ۴۵٬۰۰۰'));
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

  test('full statement includes canonical gross account movements', () {
    final when = DateTime.utc(2026, 9, 11, 16, 42);
    final deal = ZarDeal(
      id: 'deal-ledger',
      businessId: 'b',
      personId: person.id,
      type: ZarDealType.sell,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1, minorUnitScale: 0),
      ),
      pricing: ZarCurrencyDealPricing(
        tomanPerUnit: '1',
        totalToman: ZarTomanAmount(2000000000),
      ),
      dealAt: when,
      createdBy: 'u',
      createdAt: when,
      updatedAt: when,
    );
    final settlement = ZarSettlement(
      id: 'settlement-ledger',
      businessId: 'b',
      personId: person.id,
      direction: ZarSettlementDirection.receive,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(
          code: 'TOMAN',
          minorUnits: 500000000,
          minorUnitScale: 0,
        ),
      ),
      scheduledAt: when,
      hasTime: true,
      status: ZarSettlementStatus.completed,
      completedAt: when,
      createdBy: 'u',
      createdAt: when,
      updatedAt: when,
    );
    final ledger = const ZarCustomerLedgerProjector().project(
      personId: person.id,
      deals: [deal],
      settlements: [settlement],
    );
    final text = personStatementShareText(
      person: person,
      balance: ZarCustomerOperationalBalance(
        const [],
        receivableAssetBuckets: ledger.receivableAssetBuckets,
        payableAssetBuckets: ledger.payableAssetBuckets,
        projectedAssetBuckets: true,
      ),
      records: const [],
      ledger: ledger,
    );
    expect(text, contains('گردش حساب'));
    expect(text, contains('فروش'));
    expect(text, contains('دریافت'));
    expect(text, contains('۱٬۵۰۰٬۰۰۰٬۰۰۰'));
  });

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

  testWidgets(
    'person profile header keeps prioritized actions usable at 360dp',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa', 'IR'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PersonDetailScreen(
              person: AppPerson(
                id: 'p1',
                name: 'مهیار',
                phone: '۰۹۱۲۱۲۳۴۵۶۷',
                note: 'ایران‌زمین شهرکرد',
              ),
              records: const [],
              personName: (_) => 'مهیار',
              balance: balance,
              onTapRecord: (_) {},
              onEditPerson: (_) {},
              onArchivePerson: (_) {},
              onShareStatement: () {},
              onQuickEntry: () {},
              onShareBalanceBucket: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('person-primary-new-entry')), findsOneWidget);
      expect(
        find.byKey(const Key('person-primary-share-statement')),
        findsOneWidget,
      );
      expect(find.text('تماس'), findsOneWidget);
      expect(find.text('ویرایش'), findsOneWidget);
      expect(find.text('بایگانی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'person ledger rows anchor info right, amount left, and chevron far left',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settlement = AppRecord(
        id: 's1',
        type: RecordType.settlement,
        operationLabel: 'دریافت',
        personId: person.id,
        amountDisplay: '۱۰۰',
        assetLabel: 'ارز',
        currencyCode: 'USD',
        date: Jalali(1405, 6, 18),
        time: const TimeOfDay(hour: 16, minute: 13),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa', 'IR'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PersonDetailScreen(
              person: person,
              records: [settlement],
              personName: (_) => person.name,
              balance: ZarCustomerOperationalBalance(const []),
              onTapRecord: (_) {},
              onEditPerson: (_) {},
              onArchivePerson: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chevron = tester.getTopLeft(
        find.byIcon(CupertinoIcons.chevron_left),
      );
      final amount = tester.getTopLeft(find.text('۱۰۰'));
      final operation = tester.getTopLeft(find.text('دریافت'));
      expect(chevron.dx, lessThan(amount.dx));
      expect(amount.dx, lessThan(operation.dx));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping a financial bucket opens its source running balance', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 9, 11, 10);
    final deal = ZarDeal(
      id: 'deal-trace',
      businessId: 'b',
      personId: person.id,
      type: ZarDealType.sell,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1, minorUnitScale: 0),
      ),
      pricing: ZarCurrencyDealPricing(
        tomanPerUnit: '1',
        totalToman: ZarTomanAmount(2000),
      ),
      dealAt: at,
      createdBy: 'u',
      createdAt: at,
      updatedAt: at,
    );
    final ledger = const ZarCustomerLedgerProjector().project(
      personId: person.id,
      deals: [deal],
      settlements: const [],
    );
    final projected = ZarCustomerOperationalBalance(
      const [],
      receivableAssetBuckets: ledger.receivableAssetBuckets,
      payableAssetBuckets: ledger.payableAssetBuckets,
      projectedAssetBuckets: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa', 'IR'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PersonDetailScreen(
            person: person,
            records: const [],
            personName: (_) => person.name,
            position: const ZarCustomerPosition.empty(),
            balance: projected,
            ledger: ledger,
            onTapRecord: (_) {},
            onEditPerson: (_) {},
            onArchivePerson: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('۲٬۰۰۰'));
    await tester.pumpAndSettle();
    expect(find.text('منشأ مانده'), findsOneWidget);
    expect(find.text('فروش'), findsWidgets);
    expect(find.textContaining('مانده پس از این رویداد'), findsOneWidget);
    expect(find.textContaining('باید از او بگیرم'), findsWidgets);
  });
}
