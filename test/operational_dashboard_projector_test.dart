import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_app/application/operational_dashboard_projector.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/main_phase_a2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          completed('gold-750', gold('10', '750')),
          completed('gold-995', gold('20', '995')),
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
            dashboard: dashboard,
            now: now,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('۲ عیار'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('۲ عیار'), findsOneWidget);
      expect(find.text('۱ مورد'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
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
