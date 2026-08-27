import '../domain/zar_domain_models.dart';

/// Repository boundary used by the production application layer.
///
/// UI code must depend on this contract rather than Firestore directly so the
/// same workflows can be exercised against deterministic in-memory data in
/// tests and previews.
abstract interface class ZarDomainRepository {
  Future<List<ZarPerson>> loadActivePeople({int limit = 100});

  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100});

  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  });

  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  });

  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 250});

  Future<List<ZarDeal>> loadRecentDeals({int limit = 250});

  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  });

  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  });

  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'});

  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'});

  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  });

  Future<void> archivePerson(ZarPerson person);

  Future<void> restorePerson(ZarPerson person);
}

class InMemoryZarDomainRepository implements ZarDomainRepository {
  InMemoryZarDomainRepository({
    Iterable<ZarPerson> people = const [],
    Iterable<ZarDeal> deals = const [],
    Iterable<ZarSettlement> settlements = const [],
  })  : _people = {for (final item in people) item.id: item},
        _deals = {for (final item in deals) item.id: item},
        _settlements = {for (final item in settlements) item.id: item};

  final Map<String, ZarPerson> _people;
  final Map<String, ZarDeal> _deals;
  final Map<String, ZarSettlement> _settlements;
  final List<Map<String, Object?>> auditEvents = [];

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) async => _people.values
      .where((item) => !item.archived)
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) async => _people.values
      .where((item) => item.archived)
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  }) async {
    final result = _settlements.values
        .where((item) => item.isOpen)
        .where((item) => !item.scheduledAt.isBefore(from))
        .where((item) => item.scheduledAt.isBefore(through))
        .toList(growable: false)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) async {
    final result = _settlements.values
        .where((item) => item.isOpen && item.scheduledAt.isBefore(now))
        .toList(growable: false)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 250}) async {
    final result = _settlements.values.toList(growable: false)
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarDeal>> loadRecentDeals({int limit = 250}) async {
    final result = _deals.values.toList(growable: false)
      ..sort((a, b) => b.dealAt.compareTo(a.dealAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  }) async {
    final result = _settlements.values
        .where((item) => item.personId == personId)
        .toList(growable: false)
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  }) async {
    final result = _deals.values
        .where((item) => item.personId == personId)
        .toList(growable: false)
      ..sort((a, b) => b.dealAt.compareTo(a.dealAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) async {
    final existed = _people.containsKey(person.id);
    _people[person.id] = person;
    _audit(person.id, 'person', existed ? auditAction : 'create');
  }

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) async {
    final existed = _deals.containsKey(deal.id);
    _deals[deal.id] = deal;
    _audit(deal.id, 'deal', existed ? auditAction : 'create');
  }

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) async {
    final existed = _settlements.containsKey(settlement.id);
    _settlements[settlement.id] = settlement;
    _audit(settlement.id, 'settlement', existed ? auditAction : 'create');
  }

  @override
  Future<void> archivePerson(ZarPerson person) async {
    await savePerson(_copyPerson(person, archived: true), auditAction: 'archive');
  }

  @override
  Future<void> restorePerson(ZarPerson person) async {
    await savePerson(_copyPerson(person, archived: false), auditAction: 'restore');
  }

  ZarPerson _copyPerson(ZarPerson person, {required bool archived}) => ZarPerson(
        id: person.id,
        displayName: person.displayName,
        phone: person.phone,
        note: person.note,
        archived: archived,
        createdAt: person.createdAt,
        updatedAt: DateTime.now().toUtc(),
        createdBy: person.createdBy,
      );

  void _audit(String recordId, String recordType, String action) {
    auditEvents.add({
      'recordId': recordId,
      'recordType': recordType,
      'action': action,
      'createdAt': DateTime.now().toUtc(),
    });
  }
}
