import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/application/persisted_reminder_coordinator.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_reminder_plan.dart';
import 'package:flutter_app/features/reminders/record_reminder_registry.dart';
import 'package:flutter_app/features/reminders/reminder_scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);
  const bridge = ZarLegacyPresentationBridge(businessId: 'b1', userId: 'u1');

  ZarPerson person() => ZarPerson(
        id: 'p1',
        displayName: 'علی رضایی',
        createdAt: now,
        updatedAt: now,
        createdBy: 'u1',
      );

  ZarSettlement settlement() => ZarSettlement(
        id: 's1',
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.receive,
        amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
        scheduledAt: DateTime.utc(2026, 8, 27, 13),
        hasTime: true,
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

  Future<({ZarPhaseA2Store store, PersistedReminderCoordinator coordinator, InMemoryReminderScheduler scheduler, AppRecord record})>
      build() async {
    final repository = InMemoryZarDomainRepository(
      people: [person()],
      settlements: [settlement()],
    );
    final store = ZarPhaseA2Store(
      repository: repository,
      bridge: bridge,
      clock: () => now,
    );
    await store.refresh();
    final scheduler = InMemoryReminderScheduler();
    final registry = RecordReminderRegistry(scheduler: scheduler);
    final coordinator = PersistedReminderCoordinator(
      store: store,
      registry: registry,
      personName: store.personName,
    );
    return (
      store: store,
      coordinator: coordinator,
      scheduler: scheduler,
      record: store.recordById('s1')!,
    );
  }

  test('savePlan persists intent and then reconciles scheduled reminders', () async {
    final state = await build();
    const plan = ZarReminderPlan(
      rules: [
        ZarReminderRule.offset(id: '30m', minutesBefore: 30),
        ZarReminderRule.offset(id: '60m', minutesBefore: 60),
      ],
    );

    await state.coordinator.savePlan(record: state.record, plan: plan);

    expect(state.store.reminderPlanFor('s1').rules, hasLength(2));
    final pending = await state.scheduler.pendingForRecord('s1');
    expect(pending, hasLength(2));
    expect(
      pending.map((item) => item.scheduledAt).toSet(),
      containsAll(<DateTime>{
        DateTime(2026, 8, 27, 12),
        DateTime(2026, 8, 27, 12, 30),
      }),
    );
  });

  test('snooze becomes persistent business state before reconciliation', () async {
    final state = await build();
    final until = DateTime.utc(2026, 8, 27, 14, 15);

    await state.coordinator.snooze(record: state.record, until: until);

    expect(state.store.reminderPlanFor('s1').snoozedUntil, until);
    final pending = await state.scheduler.pendingForRecord('s1');
    expect(pending.single.scheduledAt, until.toLocal());
  });

  test('clearAll removes persistent and scheduled reminders', () async {
    final state = await build();
    await state.coordinator.savePlan(
      record: state.record,
      plan: const ZarReminderPlan(
        rules: [ZarReminderRule.offset(id: '15m', minutesBefore: 15)],
      ),
    );

    await state.coordinator.clearAll(state.record);

    expect(state.store.reminderPlanFor('s1').isEmpty, isTrue);
    expect(await state.scheduler.pendingForRecord('s1'), isEmpty);
  });

  test('deal records are rejected', () async {
    final state = await build();
    final deal = AppRecord(
      id: 'd1',
      type: RecordType.deal,
      operationLabel: 'خرید',
      personId: 'p1',
      amountDisplay: '۱۰۰',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 10, minute: 0),
    );

    expect(
      () => state.coordinator.savePlan(
        record: deal,
        plan: const ZarReminderPlan(),
      ),
      throwsArgumentError,
    );
  });
}
