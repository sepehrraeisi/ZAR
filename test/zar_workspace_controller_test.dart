import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/application/zar_workspace_controller.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 12);

  ZarPerson person(String id, {bool archived = false}) => ZarPerson(
        id: id,
        displayName: id == 'p1' ? 'علی رضایی' : 'رضا محمدی',
        archived: archived,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
        createdBy: 'u1',
      );

  ZarSettlement settlement(String id, DateTime scheduledAt) => ZarSettlement(
        id: id,
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.receive,
        amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
        scheduledAt: scheduledAt,
        hasTime: true,
        createdBy: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

  test('refresh loads active/archive and operational obligations', () async {
    final repo = InMemoryZarDomainRepository(
      people: [person('p1'), person('p2', archived: true)],
      settlements: [
        settlement('overdue', now.subtract(const Duration(hours: 2))),
        settlement('today', now.add(const Duration(hours: 2))),
      ],
    );
    final controller = ZarWorkspaceController(repository: repo, clock: () => now);

    await controller.refreshOperationalWindow();

    expect(controller.activePeople.map((e) => e.id), ['p1']);
    expect(controller.archivedPeople.map((e) => e.id), ['p2']);
    expect(controller.overdue.map((e) => e.id), ['overdue']);
    expect(controller.scheduledWindow.map((e) => e.id), ['today']);
    expect(controller.lastError, isNull);
  });

  test('archive and restore move a person without deleting history', () async {
    final p = person('p1');
    final repo = InMemoryZarDomainRepository(
      people: [p],
      settlements: [settlement('s1', now.add(const Duration(hours: 1)))],
    );
    final controller = ZarWorkspaceController(repository: repo, clock: () => now);
    await controller.refreshOperationalWindow();

    await controller.archivePerson(p);
    expect(controller.activePeople, isEmpty);
    expect(controller.archivedPeople.single.id, 'p1');
    expect((await repo.loadPersonSettlements(personId: 'p1')).single.id, 's1');

    await controller.restorePerson(controller.archivedPeople.single);
    expect(controller.archivedPeople, isEmpty);
    expect(controller.activePeople.single.id, 'p1');
  });

  test('complete removes obligation and persists completed timestamp', () async {
    final s = settlement('s1', now.add(const Duration(hours: 1)));
    final repo = InMemoryZarDomainRepository(people: [person('p1')], settlements: [s]);
    final controller = ZarWorkspaceController(repository: repo, clock: () => now);
    await controller.refreshOperationalWindow();

    await controller.completeSettlement(s);

    expect(controller.scheduledWindow, isEmpty);
    final saved = (await repo.loadPersonSettlements(personId: 'p1')).single;
    expect(saved.status, ZarSettlementStatus.completed);
    expect(saved.completedAt, now);
  });

  test('reschedule moves obligation between upcoming and overdue buckets', () async {
    final s = settlement('s1', now.add(const Duration(hours: 1)));
    final repo = InMemoryZarDomainRepository(people: [person('p1')], settlements: [s]);
    final controller = ZarWorkspaceController(repository: repo, clock: () => now);
    await controller.refreshOperationalWindow();

    final updated = await controller.rescheduleSettlement(
      s,
      scheduledAt: now.subtract(const Duration(minutes: 5)),
      hasTime: true,
    );

    expect(updated.scheduledAt, now.subtract(const Duration(minutes: 5)));
    expect(controller.scheduledWindow, isEmpty);
    expect(controller.overdue.single.id, 's1');
  });
}
