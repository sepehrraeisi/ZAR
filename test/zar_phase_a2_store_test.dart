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

  ZarPerson person(String id, {bool archived = false}) => ZarPerson(
        id: id,
        displayName: id == 'p1' ? 'علی رضایی' : 'رضا محمدی',
        archived: archived,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
        createdBy: 'u1',
      );

  ZarSettlement settlement({
    required String id,
    ZarSettlementStatus status = ZarSettlementStatus.open,
  }) =>
      ZarSettlement(
        id: id,
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.receive,
        amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
        scheduledAt: now.add(const Duration(hours: 3)),
        hasTime: true,
        status: status,
        completedAt: status == ZarSettlementStatus.completed ? now : null,
        completedBy: status == ZarSettlementStatus.completed ? 'u1' : null,
        createdBy: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

  test('refresh maps production domain data into current UI models', () async {
    final repo = InMemoryZarDomainRepository(
      people: [person('p1'), person('p2', archived: true)],
      settlements: [settlement(id: 's1')],
    );
    final store = ZarPhaseA2Store(
      repository: repo,
      bridge: bridge,
      clock: () => now,
    );

    await store.refresh();

    expect(store.activePeople.single.name, 'علی رضایی');
    expect(store.archivedPeople.single.name, 'رضا محمدی');
    expect(store.records.single.id, 's1');
    expect(store.records.single.amountDisplay, '۲۵۰');
  });

  test('complete settlement persists through repository and updates presentation', () async {
    final repo = InMemoryZarDomainRepository(
      people: [person('p1')],
      settlements: [settlement(id: 's1')],
    );
    final store = ZarPhaseA2Store(repository: repo, bridge: bridge, clock: () => now);
    await store.refresh();

    final ui = store.recordById('s1')!;
    await store.completeSettlement(ui);

    expect(store.recordById('s1')!.status, SettlementStatus.completed);
    final saved = (await repo.loadPersonSettlements(personId: 'p1')).single;
    expect(saved.status, ZarSettlementStatus.completed);
    expect(saved.completedAt, now);
  });

  test('archive/restore remains visible through store collections', () async {
    final repo = InMemoryZarDomainRepository(people: [person('p1')]);
    final store = ZarPhaseA2Store(repository: repo, bridge: bridge, clock: () => now);
    await store.refresh();

    final ui = store.activePeople.single;
    await store.archivePerson(ui);
    expect(store.activePeople, isEmpty);
    expect(store.archivedPeople.single.id, 'p1');

    await store.restorePerson(store.archivedPeople.single);
    expect(store.archivedPeople, isEmpty);
    expect(store.activePeople.single.id, 'p1');
  });

  test('new currency record is stored as exact minor units', () async {
    final repo = InMemoryZarDomainRepository(people: [person('p1')]);
    final store = ZarPhaseA2Store(repository: repo, bridge: bridge, clock: () => now);
    await store.refresh();

    final record = AppRecord(
      id: 'new1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$12,345.67',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 12, minute: 30),
    );
    await store.saveRecord(record, auditAction: 'create');

    final saved = (await repo.loadPersonSettlements(personId: 'p1')).single;
    final amount = (saved.amount as ZarCurrencyAssetAmount).value;
    expect(amount.minorUnits, 1234567);
    expect(amount.code, 'USD');
  });
}
