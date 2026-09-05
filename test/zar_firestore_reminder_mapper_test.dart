import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/data/firestore/zar_firestore_mapper.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';

void main() {
  const mapper = ZarFirestoreMapper();

  test('settlement reminder plan survives Firestore mapping', () {
    final now = DateTime.utc(2026, 8, 27, 12);
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'p1',
      direction: ZarSettlementDirection.deliver,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1000000),
      ),
      scheduledAt: DateTime.utc(2026, 9, 1, 14),
      hasTime: true,
      reminderPlan: ZarReminderPlan(
        rules: [
          const ZarReminderRule.offset(id: '30m', minutesBefore: 30),
          ZarReminderRule.custom(
            id: 'custom',
            customAt: DateTime.utc(2026, 9, 1, 10),
          ),
        ],
        snoozedUntil: DateTime.utc(2026, 9, 1, 13),
      ),
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );

    final map = mapper.settlementToMap(settlement);
    final restored = mapper.settlementFromMap(
      id: 's1',
      businessId: 'b1',
      map: map,
    );

    expect(restored.reminderPlan.rules, hasLength(2));
    expect(restored.reminderPlan.rules.first.minutesBefore, 30);
    expect(
      restored.reminderPlan.rules.last.customAt,
      DateTime.utc(2026, 9, 1, 10),
    );
    expect(
      restored.reminderPlan.snoozedUntil,
      DateTime.utc(2026, 9, 1, 13),
    );
  });

  test('legacy Firestore settlement without reminderPlan remains valid', () {
    final now = DateTime.utc(2026, 8, 27, 12);
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'p1',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '2.5')),
      scheduledAt: DateTime.utc(2026, 9, 1),
      hasTime: false,
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );
    final map = mapper.settlementToMap(settlement)..remove('reminderPlan');

    final restored = mapper.settlementFromMap(
      id: 's1',
      businessId: 'b1',
      map: map,
    );

    expect(restored.reminderPlan.isEmpty, isTrue);
  });
}
