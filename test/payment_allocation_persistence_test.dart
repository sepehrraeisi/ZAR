import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'customer_operational_balance_projector_test.dart' as fixtures;

void main() {
  test(
    'schema 6 adds allocation table without changing existing records',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'zar-schema6-allocation-',
      );
      final file = File('${temp.path}/fixture.sqlite');
      final initial = ZarLocalRepository(
        ZarLocalDatabase(NativeDatabase(file)),
      );
      await initial.ensureReady();
      await initial.savePerson(
        ZarPerson(
          id: 'p',
          displayName: 'مشتری قبلی',
          archived: true,
          createdAt: fixtures.at,
          updatedAt: fixtures.at,
          createdBy: 'test',
        ),
      );
      await initial.saveDeal(fixtures.deal(ZarDealType.buy));
      await initial.saveSettlement(
        fixtures.payment(ZarSettlementDirection.deliver),
      );
      final before = await initial.loadCompleteSnapshot();
      await initial.close();
      // Only a disposable fixture is rolled back to the previous table set.
      final migrated = ZarLocalRepository(
        ZarLocalDatabase(
          NativeDatabase(
            file,
            setup: (raw) {
              raw.execute('DROP TABLE zar_payment_allocations');
              raw.execute(
                "UPDATE zar_local_metadata SET value = '6' WHERE key = 'domain_schema_version'",
              );
              raw.userVersion = 6;
            },
          ),
        ),
      );
      await migrated.ensureReady();
      final after = await migrated.loadCompleteSnapshot();
      expect(after.people.single.archived, isTrue);
      expect(
        after.deals.single.pricing!.totalToman.wholeTomans,
        before.deals.single.pricing!.totalToman.wholeTomans,
      );
      expect(after.settlements.single.status, before.settlements.single.status);
      expect(
        after.settlements.single.completedAt,
        before.settlements.single.completedAt,
      );
      expect(after.paymentAllocations, isEmpty);
      await migrated.savePaymentAllocations('payment', [fixtures.allocation()]);
      expect(
        (await migrated.loadCompleteSnapshot()).paymentAllocations,
        hasLength(1),
      );
      await migrated.close();
      await temp.delete(recursive: true);
    },
  );
  test(
    'allocation survives restart and V6 restore; failed change is atomic',
    () async {
      final temp = await Directory.systemTemp.createTemp('zar-allocation-');
      final file = File('${temp.path}/test.sqlite');
      var repository = ZarLocalRepository(
        ZarLocalDatabase(NativeDatabase(file)),
      );
      await repository.ensureReady();
      final person = ZarPerson(
        id: 'p',
        displayName: 'آزمایش',
        createdAt: fixtures.at,
        updatedAt: fixtures.at,
        createdBy: 'test',
      );
      await repository.savePerson(person);
      await repository.saveDeal(fixtures.deal(ZarDealType.sell));
      await repository.saveSettlement(
        fixtures.payment(ZarSettlementDirection.receive),
      );
      await repository.savePaymentAllocations('payment', [
        fixtures.allocation(),
      ]);
      await repository.close();
      repository = ZarLocalRepository(ZarLocalDatabase(NativeDatabase(file)));
      await repository.ensureReady();
      final snapshot = await repository.loadCompleteSnapshot();
      expect(snapshot.paymentAllocations.single.amount.wholeTomans, 500000000);
      await expectLater(
        repository.savePaymentAllocations('payment', [
          fixtures.allocation(amount: 500000001),
        ]),
        throwsFormatException,
      );
      expect(
        (await repository.loadCompleteSnapshot())
            .paymentAllocations
            .single
            .amount
            .wholeTomans,
        500000000,
      );
      const codec = ZarDomainBackupCodec();
      final json = codec.encodeJson(
        ZarDomainBackupBundle(
          businessId: 'b',
          generatedAt: fixtures.at,
          people: snapshot.people,
          deals: snapshot.deals,
          settlements: snapshot.settlements,
          coinTypes: snapshot.coinTypes,
          paymentAllocations: snapshot.paymentAllocations,
        ),
      );
      final restored = codec.decodeJson(json);
      await repository.close();
      final empty = ZarLocalRepository(
        ZarLocalDatabase(NativeDatabase.memory()),
      );
      await empty.ensureReady();
      await empty.replaceCompleteSnapshot(
        ZarDomainSnapshot(
          people: restored.people,
          deals: restored.deals,
          settlements: restored.settlements,
          coinTypes: restored.coinTypes,
          paymentAllocations: restored.paymentAllocations,
        ),
      );
      final next = await empty.loadCompleteSnapshot();
      await expectLater(
        empty.replaceCompleteSnapshot(
          ZarDomainSnapshot(
            people: next.people,
            deals: next.deals,
            settlements: next.settlements,
            coinTypes: next.coinTypes,
            paymentAllocations: [fixtures.allocation(amount: 500000001)],
          ),
        ),
        throwsFormatException,
      );
      expect(
        (await empty.loadCompleteSnapshot())
            .paymentAllocations
            .single
            .amount
            .wholeTomans,
        500000000,
      );
      final balance = const ZarCustomerOperationalBalanceProjector().project(
        personId: 'p',
        deals: next.deals,
        settlements: next.settlements,
        allocations: next.paymentAllocations,
      );
      expect(balance.receivableToman, BigInt.from(1500000000));
      for (final version in [2, 3, 4, 5]) {
        final old = jsonDecode(json) as Map<String, dynamic>;
        old['exportVersion'] = version;
        old.remove('paymentAllocations');
        expect(codec.decodeJson(jsonEncode(old)).paymentAllocations, isEmpty);
      }
      await empty.close();
      await temp.delete(recursive: true);
    },
  );
}
