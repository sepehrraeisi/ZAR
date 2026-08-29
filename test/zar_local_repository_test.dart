import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/zar_backup_manager.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';

void main() {
  group('ZarLocalRepository', () {
    late ZarLocalDatabase database;
    late ZarLocalRepository repository;

    setUp(() async {
      database = ZarLocalDatabase(NativeDatabase.memory());
      repository = ZarLocalRepository(database);
      await repository.ensureReady();
    });

    tearDown(() => repository.close());

    test('persists person, archive state, and exact deal amounts', () async {
      final person = _person();
      await repository.savePerson(person);
      await repository.saveDeal(_currencyDeal());
      await repository.saveDeal(_goldDeal());
      await repository.archivePerson(person);

      final snapshot = await repository.loadCompleteSnapshot();
      expect(snapshot.people.single.archived, isTrue);
      expect(snapshot.deals, hasLength(2));

      final currency =
          snapshot.deals
                  .singleWhere((deal) => deal.id == 'deal-currency')
                  .amount
              as ZarCurrencyAssetAmount;
      expect(currency.value.minorUnits, 123456789);
      expect(currency.value.minorUnitScale, 3);
      expect(currency.value.code, 'USD');

      final gold =
          snapshot.deals.singleWhere((deal) => deal.id == 'deal-gold').amount
              as ZarGoldAssetAmount;
      expect(gold.value.decimal, '12.3456789');
      expect(gold.value.unit, ZarGoldUnit.mesghal);
      expect(gold.value.purity, '750');
    });

    test(
      'persists open, completed, and cancelled settlement lifecycles',
      () async {
        await repository.savePerson(_person());
        for (final settlement in _settlements()) {
          await repository.saveSettlement(settlement);
        }

        final restored = (await repository.loadCompleteSnapshot()).settlements;
        expect(restored.map((item) => item.status).toSet(), {
          ZarSettlementStatus.open,
          ZarSettlementStatus.completed,
          ZarSettlementStatus.cancelled,
        });
        final completed = restored.singleWhere(
          (item) => item.status == ZarSettlementStatus.completed,
        );
        expect(completed.completedAt, _at(2026, 8, 29, 12));
        expect(completed.completedBy, 'user-1');
      },
    );

    test('persists reminder rules, custom time, and snooze intent', () async {
      await repository.savePerson(_person());
      await repository.saveSettlement(_settlements().first);

      final plan = (await repository.loadCompleteSnapshot())
          .settlements
          .single
          .reminderPlan;
      expect(plan.snoozedUntil, _at(2026, 8, 30, 8, 15));
      expect(plan.rules, hasLength(2));
      expect(plan.rules.first.minutesBefore, 30);
      expect(plan.rules.last.customAt, _at(2026, 8, 29, 7, 45));
    });

    test('replace is validated before mutation and remains atomic', () async {
      await repository.savePerson(_person());
      final invalid = ZarDomainSnapshot(
        people: const [],
        deals: [_currencyDeal()],
        settlements: const [],
      );

      await expectLater(
        repository.replaceCompleteSnapshot(invalid),
        throwsFormatException,
      );
      final snapshot = await repository.loadCompleteSnapshot();
      expect(snapshot.people.single.id, 'person-1');
      expect(snapshot.deals, isEmpty);
    });
  });

  test('file-backed repository survives close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('zar-local-test-');
    final path = '${directory.path}${Platform.pathSeparator}zar.sqlite';
    try {
      var database = ZarLocalDatabase(NativeDatabase(File(path)));
      var repository = ZarLocalRepository(database);
      await repository.ensureReady();
      await repository.savePerson(_person());
      await repository.saveDeal(_goldDeal());
      await repository.saveSettlement(_settlements().first);
      await repository.close();

      database = ZarLocalDatabase(NativeDatabase(File(path)));
      repository = ZarLocalRepository(database);
      await repository.ensureReady();
      final snapshot = await repository.loadCompleteSnapshot();
      expect(snapshot.people.single.id, 'person-1');
      expect(snapshot.deals.single.id, 'deal-gold');
      expect(snapshot.settlements.single.id, 'settlement-open');
      expect(snapshot.settlements.single.reminderPlan.rules, hasLength(2));
      await repository.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'JSON V2 exports from Drift and restores into an empty database',
    () async {
      final sourceDb = ZarLocalDatabase(NativeDatabase.memory());
      final sourceRepo = ZarLocalRepository(sourceDb);
      await sourceRepo.ensureReady();
      await sourceRepo.replaceCompleteSnapshot(
        ZarDomainSnapshot(
          people: [_person()],
          deals: [_currencyDeal(), _goldDeal()],
          settlements: _settlements(),
        ),
      );
      final sourceStore = _store(sourceRepo);
      await sourceStore.refresh();
      final sourceManager = _manager(sourceRepo, sourceStore);
      final json = await sourceManager.createJson();
      await sourceRepo.close();

      final targetDb = ZarLocalDatabase(NativeDatabase.memory());
      final targetRepo = ZarLocalRepository(targetDb);
      await targetRepo.ensureReady();
      final targetStore = _store(targetRepo);
      final targetManager = _manager(targetRepo, targetStore);
      await targetManager.restore(targetManager.preview(json));

      final restored = await targetRepo.loadCompleteSnapshot();
      expect(restored.people.single.archived, isFalse);
      expect(restored.deals, hasLength(2));
      expect(restored.settlements, hasLength(3));
      final gold =
          restored.deals.singleWhere((item) => item.id == 'deal-gold').amount
              as ZarGoldAssetAmount;
      expect(gold.value.decimal, '12.3456789');
      final currency =
          restored.deals
                  .singleWhere((item) => item.id == 'deal-currency')
                  .amount
              as ZarCurrencyAssetAmount;
      expect(currency.value.minorUnits, 123456789);
      expect(restored.settlements.first.reminderPlan.rules, hasLength(2));

      await targetRepo.close();
    },
  );
}

ZarPhaseA2Store _store(ZarDomainRepository repository) => ZarPhaseA2Store(
  repository: repository,
  bridge: const ZarLegacyPresentationBridge(
    businessId: 'preview-business',
    userId: 'user-1',
  ),
);

ZarBackupManager _manager(
  ZarDomainRepository repository,
  ZarPhaseA2Store store,
) => ZarBackupManager(
  repository: repository,
  store: store,
  businessId: 'preview-business',
  reconcileRemindersAfterRestore: () async {},
  clock: () => _at(2026, 8, 29, 14),
);

ZarPerson _person() => ZarPerson(
  id: 'person-1',
  displayName: 'سارا احمدی',
  phone: '09120000000',
  note: 'مشتری قدیمی',
  createdAt: _at(2026, 8, 1),
  updatedAt: _at(2026, 8, 2),
  createdBy: 'user-1',
);

ZarDeal _currencyDeal() => ZarDeal(
  id: 'deal-currency',
  businessId: 'preview-business',
  type: ZarDealType.buy,
  personId: 'person-1',
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'usd', minorUnits: 123456789, minorUnitScale: 3),
  ),
  dealAt: _at(2026, 8, 20, 10, 30),
  createdBy: 'user-1',
  createdAt: _at(2026, 8, 20, 10),
  updatedAt: _at(2026, 8, 20, 10, 30),
);

ZarDeal _goldDeal() => ZarDeal(
  id: 'deal-gold',
  businessId: 'preview-business',
  type: ZarDealType.sell,
  personId: 'person-1',
  amount: ZarGoldAssetAmount(
    ZarGoldQuantity(
      decimal: '12.345678900',
      unit: ZarGoldUnit.mesghal,
      purity: '750',
    ),
  ),
  dealAt: _at(2026, 8, 21, 11),
  createdBy: 'user-1',
  createdAt: _at(2026, 8, 21, 11),
  updatedAt: _at(2026, 8, 21, 11),
);

List<ZarSettlement> _settlements() => [
  ZarSettlement(
    id: 'settlement-open',
    businessId: 'preview-business',
    personId: 'person-1',
    direction: ZarSettlementDirection.receive,
    amount: ZarGoldAssetAmount(
      ZarGoldQuantity(decimal: '0.125', purity: '999'),
    ),
    scheduledAt: _at(2026, 8, 31, 9),
    hasTime: true,
    reminderPlan: ZarReminderPlan(
      rules: [
        const ZarReminderRule.offset(id: 'offset-30', minutesBefore: 30),
        ZarReminderRule.custom(
          id: 'custom-1',
          customAt: _at(2026, 8, 29, 7, 45),
        ),
      ],
      snoozedUntil: _at(2026, 8, 30, 8, 15),
    ),
    createdBy: 'user-1',
    createdAt: _at(2026, 8, 20),
    updatedAt: _at(2026, 8, 29),
  ),
  ZarSettlement(
    id: 'settlement-completed',
    businessId: 'preview-business',
    personId: 'person-1',
    direction: ZarSettlementDirection.deliver,
    amount: ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: 'IRR', minorUnits: 987654321, minorUnitScale: 0),
    ),
    scheduledAt: _at(2026, 8, 29, 10),
    hasTime: true,
    status: ZarSettlementStatus.completed,
    completedAt: _at(2026, 8, 29, 12),
    completedBy: 'user-1',
    createdBy: 'user-1',
    createdAt: _at(2026, 8, 20),
    updatedAt: _at(2026, 8, 29, 12),
  ),
  ZarSettlement(
    id: 'settlement-cancelled',
    businessId: 'preview-business',
    personId: 'person-1',
    direction: ZarSettlementDirection.receive,
    amount: ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: 'EUR', minorUnits: 12345),
    ),
    scheduledAt: _at(2026, 9, 1),
    hasTime: false,
    status: ZarSettlementStatus.cancelled,
    createdBy: 'user-1',
    createdAt: _at(2026, 8, 20),
    updatedAt: _at(2026, 8, 28),
  ),
];

DateTime _at(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);
