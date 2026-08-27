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
        ZarGoldQuantity(decimal: '250.125', purity: '18K'),
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
    expect(restoredGold.value.purity, '18K');
    final restoredSettlement = decoded.settlements.single;
    final restoredCurrency = restoredSettlement.amount as ZarCurrencyAssetAmount;
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

    final json = codec.encodeJson(source).replaceFirst(
      RegExp(r',\s*"reminderPlan"\s*:\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true),
      '',
    );
    final decoded = codec.decodeJson(json);
    expect(decoded.settlements.single.reminderPlan.isEmpty, isTrue);
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
