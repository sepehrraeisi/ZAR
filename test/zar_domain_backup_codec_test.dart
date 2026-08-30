import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';

void main() {
  const codec = ZarDomainBackupCodec();
  final created = DateTime.utc(2026, 8, 27, 12);

  test('round-trips exact financial values and reminder intent', () {
    final person = ZarPerson(
      id: 'p1',
      displayName: 'علی رضایی',
      createdAt: created,
      updatedAt: created,
      createdBy: 'u1',
    );
    final deal = ZarDeal(
      id: 'd1',
      businessId: 'b1',
      type: ZarDealType.buy,
      personId: 'p1',
      amount: ZarGoldAssetAmount(
        ZarGoldQuantity(decimal: '250.125', purity: '750'),
      ),
      pricing: ZarGoldDealPricing(
        fineness: 750,
        inputWeight: '250.125',
        pricePerGramToman: ZarTomanAmount(4850123),
        totalToman: ZarTomanAmount(1213141592),
      ),
      dealAt: DateTime.utc(2026, 8, 27, 13),
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      dealId: 'd1',
      personId: 'p1',
      direction: ZarSettlementDirection.deliver,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1000050),
      ),
      scheduledAt: DateTime.utc(2026, 8, 28, 10, 30),
      hasTime: true,
      reminderPlan: ZarReminderPlan(
        rules: [
          const ZarReminderRule.offset(id: 'one-hour', minutesBefore: 60),
          ZarReminderRule.custom(
            id: 'custom',
            customAt: DateTime.utc(2026, 8, 28, 8, 15),
          ),
        ],
        snoozedUntil: DateTime.utc(2026, 8, 28, 9, 45),
      ),
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );

    final source = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: created,
      people: [person],
      deals: [deal],
      settlements: [settlement],
    );

    final decoded = codec.decodeJson(codec.encodeJson(source));

    expect(decoded.businessId, 'b1');
    final restoredGold = decoded.deals.single.amount as ZarGoldAssetAmount;
    expect(restoredGold.value.decimal, '250.125');
    expect(restoredGold.value.purity, '750');
    final restoredPricing = decoded.deals.single.pricing as ZarGoldDealPricing;
    expect(restoredPricing.fineness, 750);
    expect(restoredPricing.pricePerGramToman.wholeTomans, 4850123);
    expect(restoredPricing.totalToman.wholeTomans, 1213141592);
    final restoredSettlement = decoded.settlements.single;
    final restoredCurrency =
        restoredSettlement.amount as ZarCurrencyAssetAmount;
    expect(restoredCurrency.value.code, 'USD');
    expect(restoredCurrency.value.minorUnits, 1000050);
    expect(restoredSettlement.reminderPlan.rules, hasLength(2));
    expect(restoredSettlement.reminderPlan.rules.first.minutesBefore, 60);
    expect(
      restoredSettlement.reminderPlan.rules.last.customAt,
      DateTime.utc(2026, 8, 28, 8, 15),
    );
    expect(
      restoredSettlement.reminderPlan.snoozedUntil,
      DateTime.utc(2026, 8, 28, 9, 45),
    );
  });

  test('old v2 settlement without reminderPlan restores safely', () {
    final source = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: created,
      people: [
        ZarPerson(
          id: 'p1',
          displayName: 'علی رضایی',
          createdAt: created,
          updatedAt: created,
          createdBy: 'u1',
        ),
      ],
      deals: const [],
      settlements: [
        ZarSettlement(
          id: 's1',
          businessId: 'b1',
          personId: 'p1',
          direction: ZarSettlementDirection.receive,
          amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '1')),
          scheduledAt: DateTime.utc(2026, 8, 28),
          hasTime: false,
          createdBy: 'u1',
          createdAt: created,
          updatedAt: created,
        ),
      ],
    );

    final raw = Map<String, Object?>.from(
      jsonDecode(codec.encodeJson(source)) as Map,
    );
    raw['exportVersion'] = 2;
    final settlements = (raw['settlements']! as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList(growable: false);
    settlements.single.remove('reminderPlan');
    raw['settlements'] = settlements;

    final decoded = codec.decodeJson(jsonEncode(raw));
    expect(decoded.settlements.single.reminderPlan.isEmpty, isTrue);
  });

  test('old V3 gold pricing imports as gram pricing without loss', () {
    final source = <String, Object?>{
      'app': 'ZAR+',
      'format': 'domain-backup',
      'exportVersion': 3,
      'businessId': 'b1',
      'generatedAt': created.toIso8601String(),
      'people': [
        {
          'id': 'p1',
          'displayName': 'مهیار',
          'archived': false,
          'createdAt': created.toIso8601String(),
          'updatedAt': created.toIso8601String(),
          'createdBy': 'u1',
        },
      ],
      'deals': [
        {
          'id': 'd1',
          'type': 'buy',
          'personId': 'p1',
          'amount': {
            'assetType': 'gold',
            'gold': {'decimal': '10.25', 'unit': 'gram', 'purity': '750'},
          },
          'pricing': {
            'kind': 'gold',
            'fineness': 750,
            'pricePerGramToman': {'wholeTomans': 7000000},
            'totalToman': {'wholeTomans': 71750000},
          },
          'dealAt': created.toIso8601String(),
          'status': 'active',
          'createdBy': 'u1',
          'createdAt': created.toIso8601String(),
          'updatedAt': created.toIso8601String(),
        },
      ],
      'settlements': <Object?>[],
    };

    final restored = codec.decodeJson(jsonEncode(source)).deals.single;
    final amount = restored.amount as ZarGoldAssetAmount;
    final pricing = restored.pricing as ZarGoldDealPricing;
    expect(amount.value.decimal, '10.25');
    expect(amount.value.unit, ZarGoldUnit.gram);
    expect(pricing.inputWeight, '10.25');
    expect(pricing.inputWeightUnit, ZarGoldUnit.gram);
    expect(pricing.priceUnit, ZarGoldUnit.gram);
    expect(pricing.pricePerUnitToman.wholeTomans, 7000000);
  });

  test('old V2 deal without pricing remains importable', () {
    final raw = <String, Object?>{
      'app': 'ZAR+',
      'format': 'domain-backup',
      'exportVersion': 2,
      'businessId': 'b1',
      'generatedAt': created.toIso8601String(),
      'people': [
        {
          'id': 'p1',
          'displayName': 'علی رضایی',
          'phone': null,
          'note': null,
          'archived': false,
          'createdAt': created.toIso8601String(),
          'updatedAt': created.toIso8601String(),
          'createdBy': 'u1',
        },
      ],
      'deals': [
        {
          'id': 'd1',
          'type': 'buy',
          'personId': 'p1',
          'amount': {
            'assetType': 'currency',
            'currency': {
              'code': 'USD',
              'minorUnits': 1000000,
              'minorUnitScale': 2,
            },
          },
          'dealAt': created.toIso8601String(),
          'status': 'active',
          'note': null,
          'createdBy': 'u1',
          'createdAt': created.toIso8601String(),
          'updatedAt': created.toIso8601String(),
        },
      ],
      'settlements': <Object?>[],
    };

    final decoded = codec.decodeJson(jsonEncode(raw));
    expect(decoded.exportVersion, 2);
    expect(decoded.deals.single.id, 'd1');
    expect(decoded.deals.single.pricing, isNull);
  });

  test('rejects a settlement referencing an unknown person', () {
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'missing',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '1')),
      scheduledAt: DateTime.utc(2026, 8, 28),
      hasTime: false,
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );
    final source = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: created,
      people: const [],
      deals: const [],
      settlements: [settlement],
    );

    expect(
      () => codec.decodeJson(codec.encodeJson(source)),
      throwsA(isA<FormatException>()),
    );
  });
}
