import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_app/application/operational_inventory_projector.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/inventory/operational_inventory_screen.dart';
import 'package:flutter/material.dart';

void main() {
  const projector = ZarOperationalInventoryProjector();

  group('actual operational inventory', () {
    test('completed receive adds and deliver subtracts gold exactly', () {
      final result = projector.project(
        settlements: [
          settlement(
            'r',
            direction: ZarSettlementDirection.receive,
            amount: gold('1500.75', '750'),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'd',
            direction: ZarSettlementDirection.deliver,
            amount: gold('250.25', '750'),
            status: ZarSettlementStatus.completed,
          ),
        ],
      );
      expect(result.goldInventory.single.grams, '1250.5');
      expect(result.goldInventory.single.movements, hasLength(2));
    });

    test('keeps decimal and unknown gold fineness separate', () {
      final result = projector.project(
        settlements: [
          settlement(
            'a',
            amount: gold('1.25', '999.9'),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'b',
            amount: gold('50', null),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'c',
            amount: gold('80', '740'),
            status: ZarSettlementStatus.completed,
          ),
        ],
      );
      expect(result.goldInventory.map((e) => e.fineness).toSet(), {
        '999.9',
        null,
        '740',
      });
    });

    test('keeps USD AED and Toman cash separate with exact decimals', () {
      final result = projector.project(
        settlements: [
          settlement(
            'usd',
            amount: currency('USD', 1250050, 2),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'aed',
            amount: currency('AED', 80000, 0),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'cash',
            amount: currency('TOMAN', 320000000, 0),
            status: ZarSettlementStatus.completed,
          ),
        ],
      );
      expect(result.currencyInventory.map((e) => e.code).toSet(), {
        'USD',
        'AED',
      });
      expect(
        result.currencyInventory
            .firstWhere((e) => e.code == 'USD')
            .decimalAmount,
        '12500.5',
      );
      expect(result.cashInventory.single.decimalAmount, '320000000');
    });

    test('keeps official and weighted coin variants first-class', () {
      final result = projector.project(
        settlements: [
          settlement(
            'coins',
            amount: ZarCoinBundleAmount([
              coin('emami', 'coin-emami', 'سکه امامی', 2),
              coin(
                'parsian',
                'coin-parsian',
                'سکه پارسیان',
                6,
                weight: '0.5',
                fineness: '750',
              ),
            ]),
            status: ZarSettlementStatus.completed,
          ),
          settlement(
            'coin-out',
            direction: ZarSettlementDirection.deliver,
            amount: ZarCoinBundleAmount([
              coin('emami-out', 'coin-emami', 'سکه امامی', 1),
            ]),
            status: ZarSettlementStatus.completed,
          ),
        ],
      );
      expect(result.coinInventory, hasLength(2));
      expect(
        result.coinInventory
            .firstWhere((e) => e.displayName == 'سکه امامی')
            .quantity,
        1,
      );
      expect(
        result.coinInventory
            .firstWhere((e) => e.displayName.contains('پارسیان'))
            .displayName,
        contains('0.5 گرم'),
      );
    });
  });

  group('pending and lifecycle', () {
    test('open settlements appear only in matching pending side', () {
      final result = projector.project(
        settlements: [
          settlement('receive', amount: gold('200', '750')),
          settlement(
            'deliver',
            direction: ZarSettlementDirection.deliver,
            amount: currency('USD', 500000, 2),
          ),
        ],
      );
      expect(result.goldInventory, isEmpty);
      expect(result.currencyInventory, isEmpty);
      expect(result.pendingReceive.single, isA<ZarGoldInventoryItem>());
      expect(result.pendingDeliver.single, isA<ZarCurrencyInventoryItem>());
    });

    test('cancelled settlement affects neither actual nor pending', () {
      final result = projector.project(
        settlements: [
          settlement(
            'cancelled',
            amount: gold('500', '750'),
            status: ZarSettlementStatus.cancelled,
          ),
        ],
      );
      expect(result.goldInventory, isEmpty);
      expect(result.pendingReceive, isEmpty);
    });

    test('same stored state is deterministic and never double counts', () {
      final records = [
        settlement(
          'once',
          amount: currency('USD', 1000000, 2),
          status: ZarSettlementStatus.completed,
        ),
      ];
      final first = projector.project(settlements: records);
      final afterRestart = projector.project(settlements: records);
      expect(first.currencyInventory.single.decimalAmount, '10000');
      expect(afterRestart.currencyInventory.single.decimalAmount, '10000');
    });

    test('repository close and reopen produces the same projection', () async {
      final directory = await Directory.systemTemp.createTemp('zar_inventory_');
      final file = File(
        '${directory.path}${Platform.pathSeparator}inventory.sqlite',
      );
      try {
        var database = ZarLocalDatabase(NativeDatabase(file));
        var repository = ZarLocalRepository(database);
        await repository.savePerson(
          ZarPerson(
            id: 'person',
            displayName: 'علی',
            createdAt: _time,
            updatedAt: _time,
            createdBy: 'user',
          ),
        );
        await repository.saveSettlement(
          settlement(
            'persisted',
            amount: gold('125.5', '750'),
            status: ZarSettlementStatus.completed,
          ),
          auditAction: 'create',
        );
        await database.close();

        database = ZarLocalDatabase(NativeDatabase(file));
        repository = ZarLocalRepository(database);
        final restored = await repository.loadRecentSettlements();
        final result = projector.project(settlements: restored);
        expect(result.goldInventory.single.grams, '125.5');
        await database.close();
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  testWidgets('inventory screen renders exact grouped Persian values', (
    tester,
  ) async {
    final projection = projector.project(
      settlements: [
        settlement(
          'cash-ui',
          amount: currency('TOMAN', 320000000, 0),
          status: ZarSettlementStatus.completed,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OperationalInventoryScreen(
          projection: projection,
          personName: (_) => 'علی',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('۳۲۰٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _time = DateTime.utc(2026, 9, 1, 12);

ZarSettlement settlement(
  String id, {
  ZarSettlementDirection direction = ZarSettlementDirection.receive,
  required ZarAssetAmount amount,
  ZarSettlementStatus status = ZarSettlementStatus.open,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: direction,
  amount: amount,
  scheduledAt: _time,
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed ? _time : null,
  completedBy: status == ZarSettlementStatus.completed ? 'user' : null,
  createdBy: 'user',
  createdAt: _time,
  updatedAt: _time,
);

ZarGoldAssetAmount gold(String value, String? fineness) =>
    ZarGoldAssetAmount(ZarGoldQuantity(decimal: value, purity: fineness));

ZarCurrencyAssetAmount currency(String code, int units, int scale) =>
    ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: code, minorUnits: units, minorUnitScale: scale),
    );

ZarCoinLine coin(
  String id,
  String typeId,
  String name,
  int quantity, {
  String? weight,
  String? fineness,
}) => ZarCoinLine(
  id: id,
  coinTypeId: typeId,
  coinTypeNameSnapshot: name,
  quantity: quantity,
  weightPerPieceGrams: weight,
  fineness: fineness,
);
