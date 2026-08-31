import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/editors/confirmed_quick_add_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('deal Quick Add requests gold purity and Toman pricing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmedQuickAddSheet(
            people: [AppPerson(id: 'p1', name: 'مهیار')],
            onSave: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('خرید'));
    await tester.pump();
    await tester.tap(find.text('طلا'));
    await tester.pump();

    expect(find.text('عیار (۱ تا ۱۰۰۰)'), findsOneWidget);
    expect(find.text('واحد وزن'), findsOneWidget);
    expect(find.text('مثقال'), findsOneWidget);
    expect(find.text('قیمت (تومان/گرم)'), findsOneWidget);
    expect(find.text('واحد قیمت'), findsOneWidget);
    expect(find.text('مبلغ کل (تومان)'), findsNothing);
    expect(find.textContaining('ریال'), findsNothing);
  });

  test('gold deal keeps fineness and exact Toman pricing', () {
    final pricing = ZarGoldDealPricing(
      fineness: 750,
      inputWeight: '250.125',
      inputWeightUnit: ZarGoldUnit.gram,
      priceUnit: ZarGoldUnit.gram,
      pricePerGramToman: ZarTomanAmount(4850123),
      totalToman: ZarTomanAmount(1213141592),
    );

    final restored =
        ZarDealPricing.fromMap(pricing.toMap()) as ZarGoldDealPricing;
    expect(restored.fineness, '750');
    expect(restored.pricePerGramToman.wholeTomans, 4850123);
    expect(restored.totalToman.wholeTomans, 1213141592);
  });

  test('gold fineness accepts exact Iranian market values from 1 to 1000', () {
    for (final value in ['705', '740', '750', '875', '916', '999.9', '1000']) {
      expect(normalizeGoldFineness(value), value);
    }
    expect(() => normalizeGoldFineness('0'), throwsFormatException);
    expect(() => normalizeGoldFineness('1000.1'), throwsFormatException);
  });

  test('mithqal conversion and pricing are exact', () {
    final pricing = ZarGoldDealPricing.calculate(
      fineness: 750,
      inputWeight: '10',
      inputWeightUnit: ZarGoldUnit.mesghal,
      priceUnit: ZarGoldUnit.mesghal,
      pricePerUnitToman: ZarTomanAmount(35000000),
    );

    expect(pricing.normalizedWeightGrams, '46.083');
    expect(pricing.totalToman.wholeTomans, 350000000);
    expect(pricing.equivalentPricePerGramToman, '7594991.64550919');
  });

  test('gram pricing exposes exact mithqal equivalents', () {
    final pricing = ZarGoldDealPricing.calculate(
      fineness: 999,
      inputWeight: '100',
      inputWeightUnit: ZarGoldUnit.gram,
      priceUnit: ZarGoldUnit.gram,
      pricePerUnitToman: ZarTomanAmount(7000000),
    );

    expect(pricing.equivalentWeightMesghal, '21.69997613');
    expect(pricing.equivalentPricePerMesghalToman, '32258100');
    expect(pricing.totalToman.wholeTomans, 700000000);
  });

  test('currency deal normalizes exact Toman-per-unit rate', () {
    final pricing = ZarCurrencyDealPricing(
      tomanPerUnit: '۹۲٬۰۰۰٫۱۲۵۰۰۰',
      totalToman: ZarTomanAmount(920000000),
    );

    expect(pricing.tomanPerUnit, '92000.125');
    expect(pricing.totalToman.wholeTomans, 920000000);
  });

  test('deal pricing cannot be attached to the wrong asset type', () {
    expect(
      () => ZarDeal(
        id: 'd1',
        businessId: 'b1',
        type: ZarDealType.buy,
        personId: 'p1',
        amount: ZarCurrencyAssetAmount(
          ZarCurrencyAmount(code: 'USD', minorUnits: 1000000),
        ),
        pricing: ZarGoldDealPricing(
          fineness: 750,
          pricePerGramToman: ZarTomanAmount(1),
          totalToman: ZarTomanAmount(1),
        ),
        dealAt: DateTime.utc(2026, 8, 30),
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 8, 30),
        updatedAt: DateTime.utc(2026, 8, 30),
      ),
      throwsFormatException,
    );
  });

  test(
    'schema 1 database migrates additively and keeps old deal rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zar-v1-migrate-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}zar.sqlite');
      try {
        final database = ZarLocalDatabase(
          NativeDatabase(
            file,
            setup: (raw) {
              raw.execute('''
              CREATE TABLE zar_deals (
                id TEXT NOT NULL PRIMARY KEY,
                business_id TEXT NOT NULL,
                type TEXT NOT NULL,
                person_id TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                gold_decimal TEXT,
                gold_unit TEXT,
                gold_purity TEXT,
                currency_code TEXT,
                currency_minor_units INTEGER,
                currency_minor_unit_scale INTEGER,
                deal_at_micros INTEGER NOT NULL,
                status TEXT NOT NULL,
                note TEXT,
                created_by TEXT NOT NULL,
                created_at_micros INTEGER NOT NULL,
                updated_at_micros INTEGER NOT NULL
              )
            ''');
              raw.execute('''
              CREATE TABLE zar_local_metadata (
                key TEXT NOT NULL PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');
              raw.execute(
                "INSERT INTO zar_local_metadata (key, value) VALUES "
                "('domain_schema_version', '1')",
              );
              raw.execute('''
              INSERT INTO zar_deals (
                id, business_id, type, person_id, asset_type,
                currency_code, currency_minor_units,
                currency_minor_unit_scale, deal_at_micros, status,
                created_by, created_at_micros, updated_at_micros
              ) VALUES (
                'legacy-deal', 'b1', 'buy', 'p1', 'currency',
                'USD', 10000, 2, 1788076800000000, 'active',
                'u1', 1788076800000000, 1788076800000000
              )
            ''');
              raw.userVersion = 1;
            },
          ),
        );

        await database.ensureReady();
        final columns = await database
            .customSelect('PRAGMA table_info(zar_deals)')
            .get();
        final names = columns.map((row) => row.read<String>('name')).toSet();
        expect(
          names,
          containsAll(<String>{
            'pricing_kind',
            'gold_fineness',
            'gold_fineness_decimal',
            'toman_rate_decimal',
            'total_toman',
            'gold_input_decimal',
            'gold_input_unit',
            'gold_price_unit',
          }),
        );
        final legacy = await database
            .customSelect(
              "SELECT id, pricing_kind FROM zar_deals WHERE id = 'legacy-deal'",
            )
            .getSingle();
        expect(legacy.read<String>('id'), 'legacy-deal');
        expect(legacy.readNullable<String>('pricing_kind'), isNull);
        await database.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
