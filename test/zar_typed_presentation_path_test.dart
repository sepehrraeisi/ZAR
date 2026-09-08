import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);
  const bridge = ZarLegacyPresentationBridge(businessId: 'b1', userId: 'u1');

  ZarPerson person() => ZarPerson(
        id: 'p1',
        displayName: 'علی رضایی',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
        createdBy: 'u1',
      );

  ZarSettlement settlement(String id, {bool completed = false}) => ZarSettlement(
        id: id,
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.receive,
        amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
        scheduledAt: now.add(const Duration(hours: 3)),
        hasTime: true,
        status: completed
            ? ZarSettlementStatus.completed
            : ZarSettlementStatus.open,
        completedAt: completed ? now : null,
        completedBy: completed ? 'u1' : null,
        createdBy: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

  ZarDeal deal(String id) => ZarDeal(
        id: id,
        businessId: 'b1',
        type: ZarDealType.buy,
        personId: 'p1',
        amount: ZarCurrencyAssetAmount(
          ZarCurrencyAmount(code: 'USD', minorUnits: 1234567),
        ),
        dealAt: now,
        createdBy: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

  test('typed entities remain separate through the presentation path', () async {
    final store = ZarPhaseA2Store(
      repository: InMemoryZarDomainRepository(
        people: [person()],
        settlements: [settlement('s1')],
        deals: [deal('d1')],
      ),
      bridge: bridge,
      clock: () => now,
    );

    await store.refresh();

    expect(store.domainPeople.single, isA<ZarPerson>());
    expect(store.settlements.single, isA<ZarSettlement>());
    expect(store.deals.single, isA<ZarDeal>());
    expect(store.recordById('d1')!.type, RecordType.deal);
    expect(store.recordById('s1')!.type, RecordType.settlement);
    expect(store.settlementById('d1'), isNull);
    expect(store.dealById('d1'), same(store.deals.single));
  });

  test('Quick Add deal save preserves the typed deal-only lifecycle', () async {
    final store = ZarPhaseA2Store(
      repository: InMemoryZarDomainRepository(people: [person()]),
      bridge: bridge,
      clock: () => now,
    );
    await store.refresh();

    await store.saveRecord(
      AppRecord(
        id: 'quick-deal',
        type: RecordType.deal,
        operationLabel: 'خرید',
        personId: 'p1',
        amountDisplay: r'$12,345.67',
        assetLabel: 'ارز',
        currencyCode: 'USD',
        date: Jalali(1405, 6, 5),
        time: const TimeOfDay(hour: 12, minute: 30),
        tomanRate: '92000.125',
        totalToman: 1135802475,
      ),
      auditAction: 'create',
    );

    expect(store.deals.single.id, 'quick-deal');
    expect(store.settlements, isEmpty);
    expect(store.settlementById('quick-deal'), isNull);
    expect(store.recordById('quick-deal')!.type, RecordType.deal);
    expect((store.deals.single.amount as ZarCurrencyAssetAmount).value.minorUnits,
        1234567);
    final pricing = store.deals.single.pricing as ZarCurrencyDealPricing;
    expect(pricing.tomanPerUnit, '92000.125');
    expect(pricing.totalToman.wholeTomans, 1135802475);
  });

  test('Home and History presentation data derives from typed state', () async {
    final store = ZarPhaseA2Store(
      repository: InMemoryZarDomainRepository(
        people: [person()],
        settlements: [settlement('open'), settlement('closed', completed: true)],
        deals: [deal('deal')],
      ),
      bridge: bridge,
      clock: () => now,
    );
    await store.refresh();

    final home = store.records.where((item) =>
        item.type == RecordType.settlement &&
        item.status == SettlementStatus.open);
    final history = store.records.where((item) =>
        item.type == RecordType.deal || item.status != SettlementStatus.open);

    expect(home.map((item) => item.id), ['open']);
    expect(history.map((item) => item.id), containsAll(['deal', 'closed']));
    expect(history.map((item) => item.id), isNot(contains('open')));
  });
}
