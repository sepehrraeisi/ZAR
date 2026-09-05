import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 12);

  ZarPerson person({bool archived = false}) => ZarPerson(
        id: 'p1',
        displayName: 'علی رضایی',
        phone: '09121234567',
        archived: archived,
        createdAt: now,
        updatedAt: now,
        createdBy: 'u1',
      );

  ZarSettlement settlement({
    String id = 's1',
    DateTime? scheduledAt,
    ZarSettlementStatus status = ZarSettlementStatus.open,
  }) => ZarSettlement(
        id: id,
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.receive,
        amount: ZarGoldAssetAmount(
          ZarGoldQuantity(decimal: '250'),
        ),
        scheduledAt: scheduledAt ?? now,
        hasTime: true,
        status: status,
        completedAt: status == ZarSettlementStatus.completed ? now : null,
        completedBy: status == ZarSettlementStatus.completed ? 'u1' : null,
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

  test('archive keeps person retrievable and restore returns to active list', () async {
    final repo = InMemoryZarDomainRepository(people: [person()]);

    await repo.archivePerson(person());
    expect(await repo.loadActivePeople(), isEmpty);
    expect((await repo.loadArchivedPeople()).single.displayName, 'علی رضایی');

    await repo.restorePerson((await repo.loadArchivedPeople()).single);
    expect((await repo.loadActivePeople()).single.id, 'p1');
    expect(await repo.loadArchivedPeople(), isEmpty);
    expect(repo.auditEvents.map((e) => e['action']), containsAll(['archive', 'restore']));
  });

  test('open window and overdue queries are deterministic', () async {
    final repo = InMemoryZarDomainRepository(
      settlements: [
        settlement(id: 'overdue', scheduledAt: now.subtract(const Duration(hours: 2))),
        settlement(id: 'today', scheduledAt: now.add(const Duration(hours: 2))),
        settlement(id: 'later', scheduledAt: now.add(const Duration(days: 2))),
        settlement(
          id: 'done',
          scheduledAt: now.subtract(const Duration(days: 1)),
          status: ZarSettlementStatus.completed,
        ),
      ],
    );

    final overdue = await repo.loadOverdueSettlements(now: now);
    expect(overdue.map((e) => e.id), ['overdue']);

    final window = await repo.loadOpenSettlements(
      from: now,
      through: now.add(const Duration(days: 1)),
    );
    expect(window.map((e) => e.id), ['today']);
  });
}
