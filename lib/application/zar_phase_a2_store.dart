import '../app_core.dart';
import '../data/zar_domain_repository.dart';
import '../domain/zar_domain_models.dart';
import '../domain/zar_reminder_plan.dart';
import 'zar_legacy_presentation_bridge.dart';

/// Repository-backed presentation store for the current Phase A.2 widgets.
///
/// This is intentionally transitional: widgets can continue consuming the
/// polished `AppPerson` / `AppRecord` presentation models while every load and
/// mutation goes through the production `ZarDomainRepository` boundary.
class ZarPhaseA2Store {
  ZarPhaseA2Store({
    required ZarDomainRepository repository,
    required ZarLegacyPresentationBridge bridge,
    DateTime Function()? clock,
  })  : _repository = repository,
        _bridge = bridge,
        _clock = clock ?? DateTime.now;

  final ZarDomainRepository _repository;
  final ZarLegacyPresentationBridge _bridge;
  final DateTime Function() _clock;

  final List<AppPerson> _people = [];
  final List<AppRecord> _records = [];
  final Map<String, ZarPerson> _domainPeople = {};
  final Map<String, ZarSettlement> _domainSettlements = {};
  final Map<String, ZarDeal> _domainDeals = {};

  bool _loading = false;
  Object? _lastError;

  bool get loading => _loading;
  Object? get lastError => _lastError;
  List<AppPerson> get people => List.unmodifiable(_people);
  List<AppRecord> get records => List.unmodifiable(_records);

  List<AppPerson> get activePeople =>
      _people.where((item) => !item.archived).toList(growable: false);
  List<AppPerson> get archivedPeople =>
      _people.where((item) => item.archived).toList(growable: false);

  Future<void> refresh() async {
    _loading = true;
    _lastError = null;
    try {
      final result = await Future.wait<Object>([
        _repository.loadActivePeople(limit: 250),
        _repository.loadArchivedPeople(limit: 250),
        _repository.loadRecentSettlements(limit: 500),
        _repository.loadRecentDeals(limit: 500),
      ]);
      final active = result[0] as List<ZarPerson>;
      final archived = result[1] as List<ZarPerson>;
      final settlements = result[2] as List<ZarSettlement>;
      final deals = result[3] as List<ZarDeal>;

      _domainPeople
        ..clear()
        ..addEntries([...active, ...archived].map((item) => MapEntry(item.id, item)));
      _domainSettlements
        ..clear()
        ..addEntries(settlements.map((item) => MapEntry(item.id, item)));
      _domainDeals
        ..clear()
        ..addEntries(deals.map((item) => MapEntry(item.id, item)));

      _people
        ..clear()
        ..addAll([...active, ...archived].map(_bridge.personToUi));
      _records
        ..clear()
        ..addAll(settlements.map(_bridge.settlementToUi))
        ..addAll(deals.map(_bridge.dealToUi));
      _records.sort(_compareRecordDescending);
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  String personName(String personId) {
    for (final person in _people) {
      if (person.id == personId) return person.name;
    }
    return 'نامشخص';
  }

  int openCountFor(String personId) => _records
      .where((item) =>
          item.personId == personId &&
          item.type == RecordType.settlement &&
          item.status == SettlementStatus.open)
      .length;

  Future<void> savePerson(AppPerson person) async {
    final domain = _bridge.personFromUi(
      person,
      existing: _domainPeople[person.id],
      now: _clock(),
    );
    await _repository.savePerson(domain);
    _domainPeople[domain.id] = domain;
    _replacePerson(_bridge.personToUi(domain));
  }

  Future<void> archivePerson(AppPerson person) async {
    final existing = _domainPeople[person.id] ??
        _bridge.personFromUi(person, now: _clock());
    await _repository.archivePerson(existing);
    final archived = _bridge.personFromUi(
      person.copyWith(archived: true),
      existing: existing,
      now: _clock(),
    );
    _domainPeople[archived.id] = archived;
    _replacePerson(_bridge.personToUi(archived));
  }

  Future<void> restorePerson(AppPerson person) async {
    final existing = _domainPeople[person.id] ??
        _bridge.personFromUi(person, now: _clock());
    await _repository.restorePerson(existing);
    final restored = _bridge.personFromUi(
      person.copyWith(archived: false),
      existing: existing,
      now: _clock(),
    );
    _domainPeople[restored.id] = restored;
    _replacePerson(_bridge.personToUi(restored));
  }

  Future<void> saveRecord(AppRecord record, {String auditAction = 'edit'}) async {
    if (record.type == RecordType.settlement) {
      final domain = _bridge.settlementFromUi(
        record,
        existing: _domainSettlements[record.id],
        now: _clock(),
      );
      await _repository.saveSettlement(domain, auditAction: auditAction);
      _domainSettlements[domain.id] = domain;
      _replaceRecord(_bridge.settlementToUi(domain));
    } else {
      final domain = _bridge.dealFromUi(
        record,
        existing: _domainDeals[record.id],
        now: _clock(),
      );
      await _repository.saveDeal(domain, auditAction: auditAction);
      _domainDeals[domain.id] = domain;
      _replaceRecord(_bridge.dealToUi(domain));
    }
  }

  ZarReminderPlan reminderPlanFor(String recordId) =>
      _domainSettlements[recordId]?.reminderPlan ?? const ZarReminderPlan();

  /// Persists reminder selection as part of the settlement business record.
  /// Native notification scheduling is performed separately after this write
  /// succeeds, so a device restart or replacement never loses user intent.
  Future<void> saveReminderPlan(
    String recordId,
    ZarReminderPlan reminderPlan, {
    String auditAction = 'reminder_update',
  }) async {
    final existing = _domainSettlements[recordId];
    if (existing == null) {
      throw StateError('Settlement $recordId is not loaded.');
    }
    final updated = ZarSettlement(
      id: existing.id,
      businessId: existing.businessId,
      dealId: existing.dealId,
      personId: existing.personId,
      direction: existing.direction,
      amount: existing.amount,
      scheduledAt: existing.scheduledAt,
      hasTime: existing.hasTime,
      status: existing.status,
      reminderPlan: reminderPlan,
      completedAt: existing.completedAt,
      completedBy: existing.completedBy,
      note: existing.note,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: _clock().toUtc(),
    );
    await _repository.saveSettlement(updated, auditAction: auditAction);
    _domainSettlements[updated.id] = updated;
  }

  Future<void> completeSettlement(AppRecord record) =>
      saveRecord(record.copyWith(status: SettlementStatus.completed), auditAction: 'complete');

  Future<void> cancelSettlement(AppRecord record) =>
      saveRecord(record.copyWith(status: SettlementStatus.cancelled), auditAction: 'cancel');

  Future<void> rescheduleSettlement(AppRecord record) =>
      saveRecord(record, auditAction: 'reschedule');

  AppPerson? personById(String id) {
    for (final person in _people) {
      if (person.id == id) return person;
    }
    return null;
  }

  AppRecord? recordById(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  ZarSettlement? settlementById(String id) => _domainSettlements[id];

  void _replacePerson(AppPerson person) {
    final index = _people.indexWhere((item) => item.id == person.id);
    if (index == -1) {
      _people.add(person);
    } else {
      _people[index] = person;
    }
  }

  void _replaceRecord(AppRecord record) {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
    _records.sort(_compareRecordDescending);
  }

  int _compareRecordDescending(AppRecord a, AppRecord b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    final aMinutes = (a.time?.hour ?? 0) * 60 + (a.time?.minute ?? 0);
    final bMinutes = (b.time?.hour ?? 0) * 60 + (b.time?.minute ?? 0);
    return bMinutes.compareTo(aMinutes);
  }
}
