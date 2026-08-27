import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  const bridge = ZarLegacyPresentationBridge(
    businessId: 'b1',
    userId: 'u1',
  );

  test('failed settlement save does not mutate presentation state', () async {
    final now = DateTime.utc(2026, 8, 27, 12);
    final original = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'p1',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
      scheduledAt: DateTime.utc(2026, 8, 28, 10),
      hasTime: true,
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );
    final base = InMemoryZarDomainRepository(settlements: [original]);
    final repository = _FailingWriteRepository(base);
    final store = ZarPhaseA2Store(
      repository: repository,
      bridge: bridge,
      clock: () => now.add(const Duration(minutes: 1)),
    );

    await store.refresh();
    final before = store.recordById('s1')!;
    expect(before.status, SettlementStatus.open);

    await expectLater(
      store.completeSettlement(before),
      throwsA(isA<StateError>()),
    );

    final after = store.recordById('s1')!;
    expect(after.status, SettlementStatus.open);
  });

  test('failed person archive keeps person active', () async {
    final now = DateTime.utc(2026, 8, 27, 12);
    final person = ZarPerson(
      id: 'p1',
      displayName: 'علی رضایی',
      createdAt: now,
      updatedAt: now,
      createdBy: 'u1',
    );
    final base = InMemoryZarDomainRepository(people: [person]);
    final repository = _FailingWriteRepository(base);
    final store = ZarPhaseA2Store(
      repository: repository,
      bridge: bridge,
      clock: () => now.add(const Duration(minutes: 1)),
    );

    await store.refresh();
    final uiPerson = store.personById('p1')!;
    await expectLater(store.archivePerson(uiPerson), throwsA(isA<StateError>()));

    expect(store.personById('p1')!.archived, isFalse);
    expect(store.activePeople.map((p) => p.id), contains('p1'));
  });
}

class _FailingWriteRepository implements ZarDomainRepository {
  _FailingWriteRepository(this.delegate);

  final ZarDomainRepository delegate;

  StateError get failure => StateError('simulated persistence failure');

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) =>
      delegate.loadActivePeople(limit: limit);

  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) =>
      delegate.loadArchivedPeople(limit: limit);

  @override
  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  }) =>
      delegate.loadOpenSettlements(from: from, through: through, limit: limit);

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) =>
      delegate.loadOverdueSettlements(now: now, limit: limit);

  @override
  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 500}) =>
      delegate.loadRecentSettlements(limit: limit);

  @override
  Future<List<ZarDeal>> loadRecentDeals({int limit = 500}) =>
      delegate.loadRecentDeals(limit: limit);

  @override
  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  }) =>
      delegate.loadPersonSettlements(personId: personId, limit: limit);

  @override
  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  }) =>
      delegate.loadPersonDeals(personId: personId, limit: limit);

  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) async {
    throw failure;
  }

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) async {
    throw failure;
  }

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) async {
    throw failure;
  }

  @override
  Future<void> archivePerson(ZarPerson person) async {
    throw failure;
  }

  @override
  Future<void> restorePerson(ZarPerson person) async {
    throw failure;
  }
}
