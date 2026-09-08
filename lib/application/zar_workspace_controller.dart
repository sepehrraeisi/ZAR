import '../data/zar_domain_repository.dart';
import '../domain/zar_domain_models.dart';

/// Application-layer state holder between Flutter UI and persistence.
///
/// This controller deliberately knows nothing about Firestore. It only depends
/// on [ZarDomainRepository], so previews/tests can use the in-memory repository
/// while production can inject the Firestore implementation later.
class ZarWorkspaceController {
  ZarWorkspaceController({
    required ZarDomainRepository repository,
    required this.clock,
  }) : _repository = repository;

  final ZarDomainRepository _repository;
  final DateTime Function() clock;

  final List<ZarPerson> _activePeople = [];
  final List<ZarPerson> _archivedPeople = [];
  final List<ZarSettlement> _overdue = [];
  final List<ZarSettlement> _window = [];

  bool _loading = false;
  Object? _lastError;

  bool get loading => _loading;
  Object? get lastError => _lastError;
  List<ZarPerson> get activePeople => List.unmodifiable(_activePeople);
  List<ZarPerson> get archivedPeople => List.unmodifiable(_archivedPeople);
  List<ZarSettlement> get overdue => List.unmodifiable(_overdue);
  List<ZarSettlement> get scheduledWindow => List.unmodifiable(_window);

  Future<void> refreshOperationalWindow({Duration horizon = const Duration(days: 8)}) async {
    _loading = true;
    _lastError = null;
    try {
      final now = clock().toUtc();
      final people = await Future.wait([
        _repository.loadActivePeople(),
        _repository.loadArchivedPeople(),
      ]);
      final obligations = await Future.wait([
        _repository.loadOverdueSettlements(now: now),
        _repository.loadOpenSettlements(from: now, through: now.add(horizon)),
      ]);

      _activePeople
        ..clear()
        ..addAll(people[0]);
      _archivedPeople
        ..clear()
        ..addAll(people[1]);
      _overdue
        ..clear()
        ..addAll(obligations[0]);
      _window
        ..clear()
        ..addAll(obligations[1]);
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  ZarPerson? personById(String id) {
    for (final person in [..._activePeople, ..._archivedPeople]) {
      if (person.id == id) return person;
    }
    return null;
  }

  Future<void> savePerson(ZarPerson person) async {
    await _repository.savePerson(person);
    _replacePerson(person);
  }

  Future<void> archivePerson(ZarPerson person) async {
    await _repository.archivePerson(person);
    _activePeople.removeWhere((item) => item.id == person.id);
    _archivedPeople.removeWhere((item) => item.id == person.id);
    _archivedPeople.add(_copyPerson(person, archived: true));
  }

  Future<void> restorePerson(ZarPerson person) async {
    await _repository.restorePerson(person);
    _archivedPeople.removeWhere((item) => item.id == person.id);
    _activePeople.removeWhere((item) => item.id == person.id);
    _activePeople.add(_copyPerson(person, archived: false));
  }

  Future<void> completeSettlement(ZarSettlement settlement) async {
    final now = clock().toUtc();
    final updated = _copySettlement(
      settlement,
      status: ZarSettlementStatus.completed,
      completedAt: now,
      completedBy: settlement.completedBy ?? settlement.createdBy,
      updatedAt: now,
    );
    await _repository.saveSettlement(updated, auditAction: 'complete');
    _removeOpenSettlement(settlement.id);
  }

  Future<void> cancelSettlement(ZarSettlement settlement) async {
    final updated = _copySettlement(
      settlement,
      status: ZarSettlementStatus.cancelled,
      clearCompletion: true,
      updatedAt: clock().toUtc(),
    );
    await _repository.saveSettlement(updated, auditAction: 'cancel');
    _removeOpenSettlement(settlement.id);
  }

  Future<ZarSettlement> rescheduleSettlement(
    ZarSettlement settlement, {
    required DateTime scheduledAt,
    required bool hasTime,
  }) async {
    final updated = _copySettlement(
      settlement,
      scheduledAt: scheduledAt.toUtc(),
      hasTime: hasTime,
      updatedAt: clock().toUtc(),
    );
    await _repository.saveSettlement(updated, auditAction: 'reschedule');
    _replaceOpenSettlement(updated);
    return updated;
  }

  void _replacePerson(ZarPerson person) {
    _activePeople.removeWhere((item) => item.id == person.id);
    _archivedPeople.removeWhere((item) => item.id == person.id);
    (person.archived ? _archivedPeople : _activePeople).add(person);
  }

  void _removeOpenSettlement(String id) {
    _overdue.removeWhere((item) => item.id == id);
    _window.removeWhere((item) => item.id == id);
  }

  void _replaceOpenSettlement(ZarSettlement settlement) {
    _removeOpenSettlement(settlement.id);
    if (!settlement.isOpen) return;
    final now = clock().toUtc();
    if (settlement.scheduledAt.isBefore(now)) {
      _overdue.add(settlement);
      _overdue.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } else {
      _window.add(settlement);
      _window.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }
  }

  ZarPerson _copyPerson(ZarPerson person, {required bool archived}) => ZarPerson(
        id: person.id,
        displayName: person.displayName,
        phone: person.phone,
        note: person.note,
        archived: archived,
        createdAt: person.createdAt,
        updatedAt: clock().toUtc(),
        createdBy: person.createdBy,
      );

  ZarSettlement _copySettlement(
    ZarSettlement source, {
    ZarSettlementStatus? status,
    DateTime? scheduledAt,
    bool? hasTime,
    DateTime? completedAt,
    String? completedBy,
    bool clearCompletion = false,
    required DateTime updatedAt,
  }) {
    return ZarSettlement(
      id: source.id,
      businessId: source.businessId,
      dealId: source.dealId,
      personId: source.personId,
      direction: source.direction,
      amount: source.amount,
      scheduledAt: scheduledAt ?? source.scheduledAt,
      hasTime: hasTime ?? source.hasTime,
      status: status ?? source.status,
      completedAt: clearCompletion ? null : (completedAt ?? source.completedAt),
      completedBy: clearCompletion ? null : (completedBy ?? source.completedBy),
      note: source.note,
      createdBy: source.createdBy,
      createdAt: source.createdAt,
      updatedAt: updatedAt,
    );
  }
}
