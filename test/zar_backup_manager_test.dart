import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/application/zar_backup_manager.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';

void main() {
  final now = DateTime.utc(2026, 8, 28, 12);
  const bridge = ZarLegacyPresentationBridge(businessId: 'b1', userId: 'u1');

  ZarDomainSnapshot completeSnapshot() {
    final person = ZarPerson(
      id: 'p1',
      displayName: 'علی رضایی',
      archived: true,
      createdAt: now,
      updatedAt: now,
      createdBy: 'u1',
    );
    final deal = ZarDeal(
      id: 'd1',
      businessId: 'b1',
      type: ZarDealType.sell,
      personId: 'p1',
      amount: ZarGoldAssetAmount(
        ZarGoldQuantity(decimal: '123.456789', purity: '18K'),
      ),
      dealAt: now,
      status: ZarDealStatus.active,
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
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
      scheduledAt: now,
      hasTime: true,
      status: ZarSettlementStatus.completed,
      reminderPlan: ZarReminderPlan(
        rules: [
          const ZarReminderRule.offset(id: '60m', minutesBefore: 60),
          ZarReminderRule.custom(
            id: 'custom',
            customAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
        snoozedUntil: now.subtract(const Duration(minutes: 15)),
      ),
      completedAt: now,
      completedBy: 'u1',
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );
    return ZarDomainSnapshot(
      people: [person],
      deals: [deal],
      settlements: [settlement],
    );
  }

  ZarBackupManager manager(
    ZarDomainRepository repository, {
    required ZarPhaseA2Store store,
    required Future<void> Function() reconcile,
  }) =>
      ZarBackupManager(
        repository: repository,
        store: store,
        businessId: 'b1',
        reconcileRemindersAfterRestore: reconcile,
        clock: () => now,
      );

  test('lossless export and replacement restore preserves all domain semantics',
      () async {
    final sourceData = completeSnapshot();
    final source = InMemoryZarDomainRepository(
      people: sourceData.people,
      deals: sourceData.deals,
      settlements: sourceData.settlements,
    );
    final sourceStore = ZarPhaseA2Store(repository: source, bridge: bridge);
    final exporter = manager(source, store: sourceStore, reconcile: () async {});
    final json = await exporter.createJson();

    final oldPerson = ZarPerson(
      id: 'old',
      displayName: 'قدیمی',
      createdAt: now,
      updatedAt: now,
      createdBy: 'u1',
    );
    final target = InMemoryZarDomainRepository(people: [oldPerson]);
    final targetStore = ZarPhaseA2Store(repository: target, bridge: bridge);
    var reconciled = 0;
    final importer = manager(
      target,
      store: targetStore,
      reconcile: () async => reconciled++,
    );
    final preview = importer.preview(json);

    expect(preview.peopleCount, 1);
    expect(preview.archivedPeopleCount, 1);
    expect(preview.dealCount, 1);
    expect(preview.settlementCount, 1);
    expect(preview.settlementReminderCount, 1);
    expect(preview.reminderRuleCount, 2);

    await importer.restore(preview);

    final restored = await target.loadCompleteSnapshot();
    expect(restored.people.single.id, 'p1');
    expect(restored.people.single.archived, isTrue);
    expect(restored.people.any((person) => person.id == 'old'), isFalse);
    expect(restored.deals.single.type, ZarDealType.sell);
    expect(restored.deals.single, isA<ZarDeal>());
    final gold = restored.deals.single.amount as ZarGoldAssetAmount;
    expect(gold.value.decimal, '123.456789');
    expect(gold.value.purity, '18K');
    final settlement = restored.settlements.single;
    expect(settlement, isA<ZarSettlement>());
    expect(settlement.status, ZarSettlementStatus.completed);
    expect(settlement.completedAt, now);
    final currency = settlement.amount as ZarCurrencyAssetAmount;
    expect(currency.value.minorUnits, 1000050);
    expect(settlement.reminderPlan.rules, hasLength(2));
    expect(settlement.reminderPlan.snoozedUntil,
        now.subtract(const Duration(minutes: 15)));
    expect(reconciled, 1);
  });

  test('corrupt and unsupported backups are rejected without mutation', () async {
    final existing = completeSnapshot();
    final repository = InMemoryZarDomainRepository(
      people: existing.people,
      deals: existing.deals,
      settlements: existing.settlements,
    );
    final store = ZarPhaseA2Store(repository: repository, bridge: bridge);
    var reconciled = 0;
    final importer = manager(
      repository,
      store: store,
      reconcile: () async => reconciled++,
    );

    expect(() => importer.preview('{broken'), throwsA(isA<FormatException>()));
    final valid = jsonDecode(await importer.createJson()) as Map<String, dynamic>;
    valid['exportVersion'] = 999;
    expect(
      () => importer.preview(jsonEncode(valid)),
      throwsA(isA<FormatException>()),
    );

    final unchanged = await repository.loadCompleteSnapshot();
    expect(unchanged.people.single.id, 'p1');
    expect(unchanged.deals.single.id, 'd1');
    expect(unchanged.settlements.single.id, 's1');
    expect(reconciled, 0);
  });

  test('failed atomic persistence never reconciles reminders', () async {
    final source = completeSnapshot();
    final repository = _FailingRestoreRepository(
      InMemoryZarDomainRepository(
        people: source.people,
        deals: source.deals,
        settlements: source.settlements,
      ),
    );
    final store = ZarPhaseA2Store(repository: repository, bridge: bridge);
    var reconciled = 0;
    final importer = manager(
      repository,
      store: store,
      reconcile: () async => reconciled++,
    );
    final preview = importer.preview(await importer.createJson());

    await expectLater(importer.restore(preview), throwsA(isA<StateError>()));
    expect(reconciled, 0);
    final unchanged = await repository.loadCompleteSnapshot();
    expect(unchanged.people.single.id, 'p1');
  });
}

class _FailingRestoreRepository implements ZarDomainRepository {
  _FailingRestoreRepository(this.delegate);
  final ZarDomainRepository delegate;

  @override
  Future<ZarDomainSnapshot> loadCompleteSnapshot() =>
      delegate.loadCompleteSnapshot();

  @override
  Future<void> replaceCompleteSnapshot(ZarDomainSnapshot snapshot) async {
    throw StateError('atomic persistence failed');
  }

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) =>
      delegate.loadActivePeople(limit: limit);
  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) =>
      delegate.loadArchivedPeople(limit: limit);
  @override
  Future<List<ZarSettlement>> loadOpenSettlements({required DateTime from, required DateTime through, int limit = 250}) =>
      delegate.loadOpenSettlements(from: from, through: through, limit: limit);
  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({required DateTime now, int limit = 100}) =>
      delegate.loadOverdueSettlements(now: now, limit: limit);
  @override
  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 250}) =>
      delegate.loadRecentSettlements(limit: limit);
  @override
  Future<List<ZarDeal>> loadRecentDeals({int limit = 250}) =>
      delegate.loadRecentDeals(limit: limit);
  @override
  Future<List<ZarSettlement>> loadPersonSettlements({required String personId, int limit = 100}) =>
      delegate.loadPersonSettlements(personId: personId, limit: limit);
  @override
  Future<List<ZarDeal>> loadPersonDeals({required String personId, int limit = 100}) =>
      delegate.loadPersonDeals(personId: personId, limit: limit);
  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) =>
      delegate.savePerson(person, auditAction: auditAction);
  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) =>
      delegate.saveDeal(deal, auditAction: auditAction);
  @override
  Future<void> saveSettlement(ZarSettlement settlement, {String auditAction = 'edit'}) =>
      delegate.saveSettlement(settlement, auditAction: auditAction);
  @override
  Future<void> archivePerson(ZarPerson person) => delegate.archivePerson(person);
  @override
  Future<void> restorePerson(ZarPerson person) => delegate.restorePerson(person);
}
