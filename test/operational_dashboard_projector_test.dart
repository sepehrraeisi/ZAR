import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/application/operational_dashboard_projector.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/main_phase_a2.dart';
import 'package:flutter_app/widgets/zar_amount_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  const projector = ZarOperationalDashboardProjector();
  final now = DateTime(2026, 9, 2, 12);

  test('today and overdue contain only actionable open settlements', () {
    final result = projector.project(
      deals: const [],
      settlements: [
        settlement('today', DateTime(2026, 9, 2, 15)),
        settlement('overdue', DateTime(2026, 9, 2, 10)),
        settlement(
          'completed',
          DateTime(2026, 9, 2, 9),
          status: ZarSettlementStatus.completed,
        ),
        settlement(
          'cancelled',
          DateTime(2026, 9, 2, 8),
          status: ZarSettlementStatus.cancelled,
        ),
      ],
      now: now,
    );
    expect(result.todaySettlementIds, ['today']);
    expect(result.overdueSettlementIds, ['overdue']);
    expect(result.actionableCount, 2);
  });

  test('pending receive and deliver counts are not netted', () {
    final result = projector.project(
      deals: const [],
      settlements: [
        settlement('r1', now.add(const Duration(days: 1))),
        settlement('r2', now.add(const Duration(days: 2))),
        settlement(
          'd1',
          now.add(const Duration(days: 1)),
          direction: ZarSettlementDirection.deliver,
        ),
      ],
      now: now,
    );
    expect(result.pendingReceiveCount, 2);
    expect(result.pendingDeliverCount, 1);
  });

  test('inventory summary preserves heterogeneous assets', () {
    final result = projector.project(
      deals: const [],
      settlements: [
        completed('g750', gold('100', '750')),
        completed('g995', gold('20', '995')),
        completed('usd', currency('USD', 500000, 2)),
        completed('aed', currency('AED', 2000000, 2)),
        completed(
          'coins',
          ZarCoinBundleAmount([
            coin('emami', 'coin-emami', 'سکه امامی', 2),
            coin('half', 'coin-half', 'نیم‌سکه', 3),
          ]),
        ),
      ],
      now: now,
    );
    expect(result.inventory.goldInventory, hasLength(2));
    expect(result.inventory.currencyInventory.map((e) => e.code).toSet(), {
      'USD',
      'AED',
    });
    expect(result.inventory.coinInventory, hasLength(2));
  });

  test(
    'recent activity combines deals and closed settlements newest first',
    () {
      final result = projector.project(
        deals: [
          deal('deal-old', now.subtract(const Duration(hours: 3))),
          deal('deal-new', now.subtract(const Duration(hours: 1))),
        ],
        settlements: [
          completed(
            'settlement-mid',
            gold('1', '750'),
            at: now.subtract(const Duration(hours: 2)),
          ),
        ],
        now: now,
      );
      expect(result.recentActivities.map((e) => e.id), [
        'deal-new',
        'settlement-mid',
        'deal-old',
      ]);
      expect(result.recentActivities.first.type, ZarDashboardActivityType.deal);
    },
  );

  test('empty snapshot produces a clean empty dashboard', () {
    final result = projector.project(
      deals: const [],
      settlements: const [],
      now: now,
    );
    expect(result.actionableCount, 0);
    expect(result.pendingReceiveCount, 0);
    expect(result.inventory.goldInventory, isEmpty);
    expect(result.recentActivities, isEmpty);
  });

  test('repository restart yields the same dashboard projection', () async {
    final directory = await Directory.systemTemp.createTemp('zar_dashboard_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}dashboard.sqlite',
    );
    try {
      var database = ZarLocalDatabase(NativeDatabase(file));
      var repository = ZarLocalRepository(database);
      await repository.savePerson(person());
      await repository.saveSettlement(
        completed('persisted', currency('TOMAN', 123456789, 0)),
        auditAction: 'create',
      );
      await database.close();
      database = ZarLocalDatabase(NativeDatabase(file));
      repository = ZarLocalRepository(database);
      final result = projector.project(
        deals: await repository.loadRecentDeals(),
        settlements: await repository.loadRecentSettlements(),
        now: now,
      );
      expect(result.inventory.cashInventory.single.decimalAmount, '123456789');
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  testWidgets(
    'Home dashboard displays operational counts with Persian digits',
    (tester) async {
      final dashboard = projector.project(
        deals: const [],
        settlements: [
          completed('gold-740', gold('10', '740')),
          completed('gold-995', gold('20', '995')),
          completed('usd', currency('USD', 20000, 0)),
          completed('aed', currency('AED', 60000, 0)),
          completed('toman', currency('TOMAN', 350000000, 0)),
          completed('gold-large', gold('1480', '750')),
          settlement('pending-r', now.add(const Duration(days: 1))),
          settlement(
            'pending-d',
            now.add(const Duration(days: 1)),
            direction: ZarSettlementDirection.deliver,
          ),
        ],
        now: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseA2HomeScreen(
            records: const <AppRecord>[],
            personName: (_) => 'علی',
            onTapRecord: (_) {},
            onOpenNotifications: () {},
            unreadCount: 0,
            onOpenInventory: () {},
            onOpenDailyReport: () {},
            dashboard: dashboard,
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('موجودی واقعی'), findsNothing);
      expect(find.text('موجودی'), findsOneWidget);
      expect(find.text('گزارش روزانه'), findsOneWidget);
      expect(find.text('دریافتنی‌ها'), findsOneWidget);
      expect(find.text('پرداختنی‌ها'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == '۱۰ گرم طلا',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == '۲۰٬۰۰۰ USD',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == '۶۰٬۰۰۰ AED',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == '۱٬۴۸۰ گرم طلا',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == '۳۵۰٬۰۰۰٬۰۰۰ تومان',
        ),
        findsNothing,
      );
      expect(find.text('۱ مورد'), findsNWidgets(2));
      final receiveCard = tester.getSize(
        find.byKey(const ValueKey('home-obligation-دریافتنی‌ها')),
      );
      final deliverCard = tester.getSize(
        find.byKey(const ValueKey('home-obligation-پرداختنی‌ها')),
      );
      expect(receiveCard.height, deliverCard.height);
      final inventoryButton = tester.getSize(
        find.widgetWithText(OutlinedButton, 'موجودی'),
      );
      final reportButton = tester.getSize(
        find.widgetWithText(OutlinedButton, 'گزارش روزانه'),
      );
      expect(inventoryButton, reportButton);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home activity rows retain complete asset units', (tester) async {
    final gold = AppRecord(
      id: 'home-gold',
      type: RecordType.deal,
      operationLabel: 'خرید',
      personId: 'person',
      amountDisplay: '۲۵۰',
      assetLabel: 'گرم طلا',
      goldFineness: '750',
      goldInputUnit: ZarGoldUnit.gram.name,
      date: Jalali.now(),
      time: const TimeOfDay(hour: 16, minute: 45),
    );
    final currency = AppRecord(
      id: 'home-currency',
      type: RecordType.deal,
      operationLabel: 'فروش',
      personId: 'person',
      amountDisplay: '۲۰٬۰۰۰ USD',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.now(),
    );
    final coin = AppRecord(
      id: 'home-coin',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'person',
      amountDisplay: '۲۵ × ربع‌سکه',
      assetLabel: 'سکه',
      coinLines: const [AppCoinLine(name: 'ربع‌سکه', quantity: 25)],
      date: Jalali.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhaseA2HomeScreen(
          records: const <AppRecord>[],
          personName: (_) => 'علی',
          onTapRecord: (_) {},
          onOpenNotifications: () {},
          unreadCount: 0,
          dashboard: projector.project(
            deals: const [],
            settlements: const [],
            now: DateTime.now(),
          ),
          recentRecords: [gold, currency, coin],
          now: DateTime.now(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('۲۵۰'), findsOneWidget);
    expect(find.text('گرم طلا'), findsOneWidget);
    expect(find.text('عیار ۷۵۰'), findsOneWidget);
    expect(find.text('امروز · ۱۶:۴۵'), findsOneWidget);
    expect(find.text('۲۰٬۰۰۰'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('۲۵'), findsOneWidget);
    expect(find.text('عدد ربع‌سکه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home header is one compact two-row surface at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PhaseA2HomeScreen(
            records: const <AppRecord>[],
            personName: (_) => 'علی',
            onTapRecord: (_) {},
            onOpenNotifications: () {},
            onOpenSettings: () {},
            unreadCount: 7,
            onOpenInventory: () {},
            onOpenDailyReport: () {},
            now: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerRect = tester.getRect(find.byKey(const ValueKey('home-header')));
    final topRowRect = tester.getRect(
      find.byKey(const ValueKey('home-header-top-row')),
    );
    final todayRect = tester.getRect(
      find.byKey(const ValueKey('home-header-today')),
    );
    final quickActionsRect = tester.getRect(
      find.byKey(const ValueKey('home-quick-actions')),
    );
    final bellRect = tester.getRect(
      find.byKey(const ValueKey('home-notification-bell')),
    );
    final settingsRect = tester.getRect(
      find.byKey(const ValueKey('home-settings-button')),
    );
    final badgeRect = tester.getRect(
      find.byKey(const ValueKey('home-notification-badge')),
    );

    expect(find.text('ZAR+'), findsOneWidget);
    expect(find.text('امروز'), findsOneWidget);
    expect(find.text(formatJalaliDate(Jalali.fromDateTime(now))), findsOneWidget);
    expect(topRowRect.height, 44);
    expect(bellRect.size, const Size(44, 44));
    expect(settingsRect.size, const Size(44, 44));
    expect(tester.getRect(find.byTooltip('اعلان‌ها')).size, const Size(44, 44));
    expect(tester.getRect(find.byTooltip('تنظیمات و داده‌ها')).size, const Size(44, 44));
    expect(badgeRect.width, lessThan(bellRect.width));
    expect(badgeRect.height, lessThan(bellRect.height));
    expect(badgeRect.left, greaterThanOrEqualTo(bellRect.left));
    expect(badgeRect.top, greaterThanOrEqualTo(bellRect.top));
    expect(badgeRect.right, lessThanOrEqualTo(bellRect.right));
    expect(badgeRect.bottom, lessThanOrEqualTo(bellRect.bottom));
    expect(todayRect.top - topRowRect.bottom, inInclusiveRange(0, 4));
    expect(quickActionsRect.top - todayRect.bottom, inInclusiveRange(16, 22));
    expect(headerRect.bottom, lessThanOrEqualTo(quickActionsRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home amount display keeps unit physically before number in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: ZarAmountDisplay(amount: '۲۰٬۰۰۰', unit: 'USD', purity: 'عیار ۷۵۰'),
          ),
        ),
      ),
    );
    final unitRect = tester.getRect(find.text('USD'));
    final amountRect = tester.getRect(find.text('۲۰٬۰۰۰'));
    expect(unitRect.left, lessThan(amountRect.left));
    expect(find.text('عیار ۷۵۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home amount display covers currency, gold, and negative values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 320,
            child: Column(
              children: [
                ZarAmountDisplay(amount: '۲۰٬۰۰۰', unit: 'USD'),
                ZarAmountDisplay(amount: '۴۵٬۰۰۰', unit: 'EUR'),
                ZarAmountDisplay(amount: '۶۰٬۰۰۰', unit: 'AED'),
                ZarAmountDisplay(amount: '۶۰۰', unit: 'GBP'),
                ZarAmountDisplay(amount: '۶۵۰٬۰۰۰', unit: 'TRY'),
                ZarAmountDisplay(amount: '۱٬۴۸۰', unit: 'گرم طلا'),
                ZarAmountDisplay(amount: '۵۶۰', unit: 'گرم طلا'),
                ZarAmountDisplay(amount: '۵۰۰', unit: 'USD', negative: true),
              ],
            ),
          ),
        ),
      ),
    );
    for (final pair in const [
      ('USD', '۲۰٬۰۰۰'),
      ('EUR', '۴۵٬۰۰۰'),
      ('AED', '۶۰٬۰۰۰'),
      ('GBP', '۶۰۰'),
      ('TRY', '۶۵۰٬۰۰۰'),
      ('گرم طلا', '۱٬۴۸۰'),
    ]) {
      final unitRect = tester.getRect(find.text(pair.$1).first);
      final amountRect = tester.getRect(find.text(pair.$2));
      expect(unitRect.left, lessThan(amountRect.left));
    }
    expect(find.text('۵۶۰'), findsOneWidget);
    expect(find.text('-۵۰۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home buy activity uses an exchange icon', (tester) async {
    final buy = AppRecord(
      id: 'home-buy',
      type: RecordType.deal,
      operationLabel: 'خرید',
      personId: 'person',
      amountDisplay: '۲۰٬۰۰۰ USD',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhaseA2HomeScreen(
          records: const <AppRecord>[],
          personName: (_) => 'علی',
          onTapRecord: (_) {},
          onOpenNotifications: () {},
          unreadCount: 0,
          recentRecords: [buy],
          now: DateTime.now(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_2_squarepath), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home obligation preview aligns person with its amount', (tester) async {
    final due = now.add(const Duration(days: 1));
    final record = AppRecord(
      id: 'home-preview',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'person',
      amountDisplay: '۲۰٬۰۰۰ USD',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.fromDateTime(due),
      time: const TimeOfDay(hour: 10, minute: 0),
      status: SettlementStatus.open,
    );
    final dashboard = projector.project(
      deals: const [],
      settlements: [settlement('home-preview', due, amount: currency('USD', 20000, 0))],
      now: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhaseA2HomeScreen(
          records: [record],
          personName: (_) => 'علی',
          onTapRecord: (_) {},
          onOpenNotifications: () {},
          unreadCount: 0,
          dashboard: dashboard,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final personRect = tester.getRect(find.text('علی').first);
    final amountRect = tester.getRect(find.text('۲۰٬۰۰۰').first);
    expect((personRect.top - amountRect.top).abs(), lessThan(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home dashboard remains readable at compact phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final dashboard = projector.project(
      deals: const [],
      settlements: [
        settlement('compact-r', now.add(const Duration(days: 1))),
        settlement('compact-d', now.add(const Duration(days: 2)), direction: ZarSettlementDirection.deliver),
      ],
      now: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhaseA2HomeScreen(
          records: const <AppRecord>[],
          personName: (_) => 'علی',
          onTapRecord: (_) {},
          onOpenNotifications: () {},
          unreadCount: 0,
          dashboard: dashboard,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('home-obligation-دریافتنی‌ها'))).height, 160);
    expect(tester.getSize(find.byKey(const ValueKey('home-obligation-پرداختنی‌ها'))).height, 160);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows same-day overdue context after its due time', (tester) async {
    final now = DateTime(2026, 9, 2, 12);
    final overdue = AppRecord(
      id: 'home-overdue',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'person',
      amountDisplay: '۵۰۰',
      assetLabel: 'گرم طلا',
      goldFineness: '750',
      date: Jalali.fromDateTime(now),
      time: const TimeOfDay(hour: 10, minute: 0),
      status: SettlementStatus.open,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhaseA2HomeScreen(
          records: [overdue],
          personName: (_) => 'علی',
          onTapRecord: (_) {},
          onOpenNotifications: () {},
          unreadCount: 0,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('عقب‌افتاده'), findsNWidgets(2));
    expect(find.text('در انتظار'), findsNothing);
  });
}

ZarPerson person() => ZarPerson(
  id: 'person',
  displayName: 'علی',
  createdAt: _base,
  updatedAt: _base,
  createdBy: 'user',
);
final _base = DateTime.utc(2026, 9, 1);

ZarSettlement settlement(
  String id,
  DateTime due, {
  ZarSettlementDirection direction = ZarSettlementDirection.receive,
  ZarSettlementStatus status = ZarSettlementStatus.open,
  ZarAssetAmount? amount,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: direction,
  amount: amount ?? gold('1', '750'),
  scheduledAt: due.toUtc(),
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed ? due.toUtc() : null,
  completedBy: status == ZarSettlementStatus.completed ? 'user' : null,
  createdBy: 'user',
  createdAt: _base,
  updatedAt: due.toUtc(),
);

ZarSettlement completed(String id, ZarAssetAmount amount, {DateTime? at}) =>
    settlement(
      id,
      at ?? _base,
      amount: amount,
      status: ZarSettlementStatus.completed,
    );

ZarDeal deal(String id, DateTime at) => ZarDeal(
  id: id,
  businessId: 'business',
  type: ZarDealType.buy,
  personId: 'person',
  amount: gold('1', '750'),
  dealAt: at.toUtc(),
  createdBy: 'user',
  createdAt: at.toUtc(),
  updatedAt: at.toUtc(),
);

ZarGoldAssetAmount gold(String decimal, String? purity) =>
    ZarGoldAssetAmount(ZarGoldQuantity(decimal: decimal, purity: purity));
ZarCurrencyAssetAmount currency(String code, int units, int scale) =>
    ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: code, minorUnits: units, minorUnitScale: scale),
    );
ZarCoinLine coin(String id, String type, String name, int quantity) =>
    ZarCoinLine(
      id: id,
      coinTypeId: type,
      coinTypeNameSnapshot: name,
      quantity: quantity,
    );
