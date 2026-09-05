import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_app/application/customer_position_projector.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';
import 'package:flutter_app/features/editors/confirmed_quick_add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final official = ZarCoinLine(
    id: 'line-emami',
    coinTypeId: 'coin-emami',
    coinTypeNameSnapshot: 'سکه امامی',
    quantity: 2,
  );
  final parsian = ZarCoinLine(
    id: 'line-parsian',
    coinTypeId: 'coin-parsian',
    coinTypeNameSnapshot: 'پارسیان ۰٫۵ گرم',
    quantity: 5,
    weightPerPieceGrams: '0.5',
    fineness: '999.9',
  );

  test('official coin pricing is exact per piece', () {
    final price = ZarCoinLinePricing.calculate(
      line: official,
      method: ZarCoinPricingMethod.perPiece,
      unitPriceToman: ZarTomanAmount(40000000),
    );
    expect(price.rowTotalToman.wholeTomans, 80000000);
  });

  test('Parsian supports arbitrary decimal weight and purity per gram', () {
    final price = ZarCoinLinePricing.calculate(
      line: parsian,
      method: ZarCoinPricingMethod.perGram,
      unitPriceToman: ZarTomanAmount(7000000),
      priceReferenceFineness: '750',
    );
    expect(price.rowTotalToman.wholeTomans, 23331000);
    expect(parsian.weightPerPieceGrams, '0.5');
    expect(parsian.fineness, '999.9');
  });

  test('Persian numeric values normalize without double', () {
    final line = ZarCoinLine(
      id: 'p',
      coinTypeId: 'coin-parsian',
      coinTypeNameSnapshot: 'پارسیان',
      quantity: int.parse(normalizeDecimal('۳')),
      weightPerPieceGrams: '۰٫۲۵',
      fineness: '۷۵۰',
    );
    expect(line.quantity, 3);
    expect(line.weightPerPieceGrams, '0.25');
    expect(line.fineness, '750');
  });

  test(
    'coin settlement valuation is optional and lifecycle stays separate',
    () {
      final settlement = _settlement([official]);
      expect(settlement.coinValuation, isNull);
      expect(settlement.status, ZarSettlementStatus.open);
      expect(settlement.amount, isA<ZarCoinBundleAmount>());
    },
  );

  test(
    'customer position aggregates only open coin settlements by identity',
    () {
      final completed = _settlement(
        [official],
        id: 'closed',
        status: ZarSettlementStatus.completed,
      );
      final position = const ZarCustomerPositionProjector().project(
        personId: 'person',
        deals: const [],
        settlements: [
          _settlement([official, parsian]),
          completed,
        ],
      );
      final coins = position.receive
          .whereType<ZarCustomerCoinPosition>()
          .toList();
      expect(coins, hasLength(2));
      expect(
        coins.singleWhere((item) => item.displayName == 'سکه امامی').quantity,
        2,
      );
      expect(
        coins
            .singleWhere((item) => item.displayName.contains('پارسیان'))
            .quantity,
        5,
      );
    },
  );

  test(
    'coin bundle and catalog persist atomically across repository reopen',
    () async {
      final db = ZarLocalDatabase(NativeDatabase.memory());
      final repo = ZarLocalRepository(db);
      await repo.ensureReady();
      await repo.savePerson(_person());
      final pricing = ZarCoinDealPricing(
        lines: [
          ZarCoinLinePricing.calculate(
            line: official,
            method: ZarCoinPricingMethod.perPiece,
            unitPriceToman: ZarTomanAmount(100000000),
          ),
          ZarCoinLinePricing.calculate(
            line: parsian,
            method: ZarCoinPricingMethod.perGram,
            unitPriceToman: ZarTomanAmount(7000000),
          ),
        ],
      );
      await repo.saveDeal(_deal([official, parsian], pricing));
      await repo.saveSettlement(_settlement([official]));
      final snapshot = await repo.loadCompleteSnapshot();
      expect(snapshot.deals.single.amount, isA<ZarCoinBundleAmount>());
      expect(
        (snapshot.deals.single.amount as ZarCoinBundleAmount).lines,
        hasLength(2),
      );
      expect(
        (snapshot.deals.single.pricing as ZarCoinDealPricing).lines,
        hasLength(2),
      );
      expect(
        (snapshot.settlements.single.amount as ZarCoinBundleAmount)
            .lines
            .single
            .quantity,
        2,
      );
      expect(snapshot.coinTypes.any((item) => item.id == 'coin-emami'), isTrue);
      await repo.close();
    },
  );

  test('catalog seeding is idempotent and never overwrites edits', () async {
    final db = ZarLocalDatabase(NativeDatabase.memory());
    final repo = ZarLocalRepository(db);
    await repo.ensureReady();
    final emami = (await repo.loadCoinTypes(
      includeArchived: true,
    )).singleWhere((item) => item.id == 'coin-emami');
    await repo.saveCoinType(
      emami.copyWith(
        name: 'نام ویرایش‌شده',
        updatedAt: DateTime.utc(2026, 8, 31),
      ),
    );
    await repo.ensureReady();
    expect(
      (await repo.loadCoinTypes(
        includeArchived: true,
      )).singleWhere((item) => item.id == 'coin-emami').name,
      'نام ویرایش‌شده',
    );
    await repo.close();
  });

  test('Backup V5 round-trips catalog and one logical multi-line deal', () {
    const codec = ZarDomainBackupCodec();
    final catalog = zarInitialCoinTypes(now: DateTime.utc(2026));
    final pricing = ZarCoinDealPricing(
      lines: [
        ZarCoinLinePricing.calculate(
          line: official,
          method: ZarCoinPricingMethod.perPiece,
          unitPriceToman: ZarTomanAmount(10),
        ),
      ],
    );
    final source = ZarDomainBackupBundle(
      businessId: 'business',
      generatedAt: DateTime.utc(2026),
      people: [_person()],
      deals: [
        _deal([official], pricing),
      ],
      settlements: [
        _settlement([official]),
      ],
      coinTypes: catalog,
    );
    final restored = codec.decodeJson(codec.encodeJson(source));
    expect(restored.exportVersion, 5);
    expect(restored.coinTypes, hasLength(7));
    expect(
      (restored.deals.single.amount as ZarCoinBundleAmount)
          .lines
          .single
          .coinTypeNameSnapshot,
      'سکه امامی',
    );
    expect(restored.settlements.single.coinValuation, isNull);
  });

  test('Backup V4 remains importable with an empty catalog', () {
    const codec = ZarDomainBackupCodec();
    final v5 = codec.encodeJson(
      ZarDomainBackupBundle(
        businessId: 'business',
        generatedAt: DateTime.utc(2026),
        people: [_person()],
        deals: const [],
        settlements: const [],
      ),
    );
    final map = Map<String, Object?>.from(jsonDecode(v5) as Map)
      ..['exportVersion'] = 4
      ..remove('coinTypes');
    final restored = codec.decodeJson(jsonEncode(map));
    expect(restored.exportVersion, 4);
    expect(restored.coinTypes, isEmpty);
  });

  test('schema 5 upgrades additively to coin schema 6', () async {
    final directory = await Directory.systemTemp.createTemp('zar-v5-coin-');
    final file = File('${directory.path}${Platform.pathSeparator}zar.sqlite');
    try {
      final db = ZarLocalDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute(
              'CREATE TABLE zar_local_metadata (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO zar_local_metadata (key, value) VALUES ('domain_schema_version', '5')",
            );
            raw.userVersion = 5;
          },
        ),
      );
      final repo = ZarLocalRepository(db);
      await repo.ensureReady();
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'zar_coin_types',
          'zar_deal_coin_lines',
          'zar_settlement_coin_lines',
        ]),
      );
      expect(await repo.loadCoinTypes(includeArchived: true), hasLength(7));
      await repo.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('presentation keeps a multi-line coin deal as one history record', () {
    const bridge = ZarLegacyPresentationBridge(
      businessId: 'business',
      userId: 'test',
    );
    final pricing = ZarCoinDealPricing(
      lines: [
        ZarCoinLinePricing.calculate(
          line: official,
          method: ZarCoinPricingMethod.perPiece,
          unitPriceToman: ZarTomanAmount(10),
        ),
        ZarCoinLinePricing.calculate(
          line: parsian,
          method: ZarCoinPricingMethod.perGram,
          unitPriceToman: ZarTomanAmount(7000000),
        ),
      ],
    );
    final record = bridge.dealToUi(_deal([official, parsian], pricing));
    expect(record.type, RecordType.deal);
    expect(record.assetLabel, 'سکه');
    expect(record.coinLines, hasLength(2));
    expect(record.amountDisplay, contains('سکه امامی'));
  });

  test(
    'coin settlement complete action preserves bundle and valuation',
    () async {
      final valuation = ZarCoinSettlementValuation(
        lines: [
          ZarCoinLinePricing.calculate(
            line: official,
            method: ZarCoinPricingMethod.perPiece,
            unitPriceToman: ZarTomanAmount(10),
          ),
        ],
      );
      final settlement = ZarSettlement(
        id: 'settlement-valued',
        businessId: 'business',
        personId: 'person',
        direction: ZarSettlementDirection.receive,
        amount: ZarCoinBundleAmount([official]),
        scheduledAt: DateTime.utc(2026),
        hasTime: false,
        coinValuation: valuation,
        createdBy: 'test',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final repo = InMemoryZarDomainRepository(
        people: [_person()],
        settlements: [settlement],
      );
      final store = ZarPhaseA2Store(
        repository: repo,
        bridge: const ZarLegacyPresentationBridge(
          businessId: 'business',
          userId: 'test',
        ),
        clock: () => DateTime.utc(2026, 9, 1),
      );
      await store.refresh();
      await store.completeSettlement(store.recordById(settlement.id)!);
      final restored = (await repo.loadCompleteSnapshot()).settlements.single;
      expect(restored.status, ZarSettlementStatus.completed);
      expect(
        (restored.amount as ZarCoinBundleAmount).lines.single.coinTypeId,
        'coin-emami',
      );
      expect(restored.coinValuation?.totalToman.wholeTomans, 20);
    },
  );

  testWidgets('Quick Add exposes coin and multiple rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmedQuickAddSheet(
            people: [AppPerson(id: 'person', name: 'مهیار')],
            coinTypes: zarInitialCoinTypes(now: DateTime.utc(2026)),
            onSave: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('خرید'));
    await tester.pump();
    await tester.tap(find.text('سکه'));
    await tester.pump();
    expect(find.text('افزودن سکه دیگر'), findsOneWidget);
    await tester.ensureVisible(find.text('افزودن سکه دیگر'));
    await tester.tap(find.text('افزودن سکه دیگر'));
    await tester.pump();
    expect(find.text('ردیف ۲'), findsOneWidget);
  });
}

ZarPerson _person() => ZarPerson(
  id: 'person',
  displayName: 'مهیار',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdBy: 'test',
);
ZarDeal _deal(List<ZarCoinLine> lines, ZarCoinDealPricing pricing) => ZarDeal(
  id: 'deal',
  businessId: 'business',
  type: ZarDealType.buy,
  personId: 'person',
  amount: ZarCoinBundleAmount(lines),
  pricing: pricing,
  dealAt: DateTime.utc(2026),
  createdBy: 'test',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
ZarSettlement _settlement(
  List<ZarCoinLine> lines, {
  String id = 'settlement',
  ZarSettlementStatus status = ZarSettlementStatus.open,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: ZarSettlementDirection.receive,
  amount: ZarCoinBundleAmount(lines),
  scheduledAt: DateTime.utc(2026),
  hasTime: false,
  status: status,
  completedAt: status == ZarSettlementStatus.completed
      ? DateTime.utc(2026)
      : null,
  reminderPlan: const ZarReminderPlan(),
  createdBy: 'test',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
