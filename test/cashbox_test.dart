import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/zar_cash_projector.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_cash_entry.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_app/features/inventory/cashbox_screen.dart';

final at = DateTime.utc(2026, 10, 2);
ZarAssetAmount money(int value) => ZarCurrencyAssetAmount(ZarCurrencyAmount(code: 'TOMAN', minorUnits: value, minorUnitScale: 0));
ZarAssetAmount gold(String value) => ZarGoldAssetAmount(ZarGoldQuantity(decimal: value, purity: '750'));
ZarPerson person() => ZarPerson(id: 'p', displayName: 'علی', createdAt: at, updatedAt: at, createdBy: 'u');
ZarDeal deal() => ZarDeal(id: 'd', businessId: 'b', type: ZarDealType.buy, personId: 'p', amount: gold('10'),
  pricing: ZarGoldDealPricing.calculate(fineness: '750', inputWeight: '10', inputWeightUnit: ZarGoldUnit.gram,
    priceUnit: ZarGoldUnit.gram, pricePerUnitToman: ZarTomanAmount(10)), dealAt: at, createdBy: 'u', createdAt: at, updatedAt: at);
ZarSettlement payment(String id, int value, {String? dealId}) => ZarSettlement(id: id, businessId: 'b', personId: 'p',
  dealId: dealId, direction: ZarSettlementDirection.deliver, amount: money(value), scheduledAt: at, hasTime: true,
  status: ZarSettlementStatus.completed, completedAt: at, createdBy: 'u', createdAt: at, updatedAt: at);
ZarCashEntry entry(String id, ZarAssetAmount amount, {ZarCashEntryKind kind = ZarCashEntryKind.contribution,
  String? dealId, DateTime? time, ZarSettlementDirection direction = ZarSettlementDirection.receive, String? reversesId}) =>
  ZarCashEntry(id: id, businessId: 'b', kind: kind, amount: amount, direction: direction,
    occurredAt: time ?? at, note: 'آزمایش', dealId: dealId, reversesId: reversesId);

void main() {
  test('physical delivery only, partial fulfilment and over-delivery rejection', () {
    final d = deal();
    final e = entry('e', gold('4'), kind: ZarCashEntryKind.delivery, dealId: d.id);
    validateCashEntries(entries: [e], deals: [d], settlements: []);
    final p = const ZarCashProjector().project(entries: [e], settlements: []);
    expect(p.balances.single.quantity, '4');
    expect(cashDeliveredForDeal(d, [e], [])['gold:750'], '4');
    expect(() => validateCashEntries(entries: [e, entry('too-much', gold('7'), kind: ZarCashEntryKind.delivery, dealId: d.id)], deals: [d], settlements: []), throwsFormatException);
    expect(const ZarCashProjector().project(entries: [], settlements: []).balances, isEmpty);
  });

  test('partial original completion agrees between cash and customer ledger', () {
    final partial = payment('partial', 40), original = payment('original', 100);
    final allocations = [ZarPaymentAllocation(settlementId: partial.id, targetType: ZarPaymentAllocationTarget.settlement,
      targetId: original.id, amount: ZarTomanAmount(40))];
    final cash = const ZarCashProjector().project(entries: [], settlements: [partial, original], allocations: allocations);
    final person = const ZarCustomerOperationalBalanceProjector().project(personId: 'p', deals: [], settlements: [partial, original], allocations: allocations);
    expect(cash.balances.single.quantity, '-100');
    expect(person.receivableToman.toString(), '100');
  });

  test('same payment linked and allocated counts only once', () {
    final p = payment('p60', 60, dealId: 'd');
    final result = const ZarCustomerLedgerProjector().accountingStatusForDeal(deal: deal(), settlements: [p],
      allocations: [ZarPaymentAllocation(settlementId: p.id, targetType: ZarPaymentAllocationTarget.deal, targetId: 'd', amount: ZarTomanAmount(60))]);
    expect(result, ZarCustomerDealAccountingStatus.partiallySettled);
  });

  test('opening cuts off older physical history; zero retains journal', () {
    final old = payment('old', 50);
    final start = entry('start', money(100), kind: ZarCashEntryKind.opening, time: at.add(const Duration(days: 1)));
    final withdraw = entry('out', money(100), kind: ZarCashEntryKind.withdrawal,
      direction: ZarSettlementDirection.deliver, time: at.add(const Duration(days: 2)));
    final p = const ZarCashProjector().project(entries: [start, withdraw], settlements: [old]);
    expect(p.balances.single.quantity, '0');
    expect(p.lines.length, 2);
    expect(p.lines.first.running, '0');
    expect(() => validateCashEntries(entries: [start, entry('duplicate', money(1), kind: ZarCashEntryKind.opening)], deals: [], settlements: []), throwsFormatException);
  });

  test('reversal restores quantity and reopens delivery without removing evidence', () {
    final original = entry('delivery', gold('4'), kind: ZarCashEntryKind.delivery, dealId: 'd');
    final reversal = entry('undo', gold('4'), kind: ZarCashEntryKind.reversal, reversesId: original.id,
      direction: ZarSettlementDirection.deliver);
    validateCashEntries(entries: [original, reversal], deals: [deal()], settlements: []);
    expect(cashDeliveredForDeal(deal(), [original, reversal], []), isEmpty);
    final p = const ZarCashProjector().project(entries: [original, reversal], settlements: []);
    expect(p.balances.single.quantity, '0');
    expect(p.lines.length, 2);
  });

  test('local journal survives restart, is immutable, and V8 backup roundtrips', () async {
    final dir = await Directory.systemTemp.createTemp('zar-cash-');
    final file = File('${dir.path}/cash.sqlite');
    var repo = ZarLocalRepository(ZarLocalDatabase(NativeDatabase(file)));
    try {
      await repo.ensureReady();
      await repo.savePerson(person());
      await repo.saveDeal(deal());
      final e = entry('delivery', gold('4'), kind: ZarCashEntryKind.delivery, dealId: 'd');
      await repo.appendCashEntry(e);
      await repo.appendCashEntry(e);
      await expectLater(repo.appendCashEntry(entry('delivery', gold('5'), kind: ZarCashEntryKind.delivery, dealId: 'd')), throwsStateError);
      await repo.close();
      repo = ZarLocalRepository(ZarLocalDatabase(NativeDatabase(file)));
      await repo.ensureReady();
      final snapshot = await repo.loadCompleteSnapshot();
      expect(snapshot.cashEntries.length, 1);
      const codec = ZarDomainBackupCodec();
      final restored = codec.decodeJson(codec.encodeJson(ZarDomainBackupBundle(businessId: 'b', generatedAt: at,
        people: snapshot.people, deals: snapshot.deals, settlements: snapshot.settlements,
        coinTypes: snapshot.coinTypes, currencyTypes: snapshot.currencyTypes, cashEntries: snapshot.cashEntries)));
      expect(restored.cashEntries.single.toMap(), e.toMap());
      await repo.replaceCompleteSnapshot(ZarDomainSnapshot(people: restored.people, deals: restored.deals,
        settlements: restored.settlements, cashEntries: restored.cashEntries));
      expect((await repo.loadCompleteSnapshot()).cashEntries.single.toMap(), e.toMap());
    } finally { await repo.close(); await dir.delete(recursive: true); }
  });

  testWidgets('cashbox opens input and saves physical opening at phone width', (tester) async {
    tester.view.physicalSize = const Size(720, 1544);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryZarDomainRepository();
    final store = ZarPhaseA2Store(repository: repo, bridge: const ZarLegacyPresentationBridge(businessId: 'b', userId: 'u'));
    await store.refresh();
    await tester.pumpWidget(MaterialApp(home: CashboxScreen(store: store, businessId: 'b', onOpenRecord: (_) {}, onChanged: () {})));
    await tester.tap(find.text('سایر عملیات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('موجودی آغازین').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cash-quantity')), '100');
    await tester.ensureVisible(find.byKey(const ValueKey('cash-save')));
    await tester.tap(find.byKey(const ValueKey('cash-save')));
    await tester.pumpAndSettle();
    expect(store.cashEntries.single.kind, ZarCashEntryKind.opening);
    expect(find.text('۱۰۰'), findsNWidgets(2));
    expect(find.text('وجه نقد (تومان)'), findsWidgets);
    expect(find.text('موجودی آغازین'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
