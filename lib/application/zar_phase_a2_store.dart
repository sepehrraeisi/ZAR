import '../app_core.dart';
import '../data/zar_domain_repository.dart';
import '../domain/zar_domain_models.dart';
import '../domain/zar_reminder_plan.dart';
import 'zar_legacy_presentation_bridge.dart';

/// Repository-backed presentation store for the current Phase A.2 widgets.
///
/// Typed domain entities are the sole owned business state. The current widgets
/// still consume `AppPerson` / `AppRecord`, so those values are derived at the
/// presentation boundary rather than retained as a second mutable state graph.
class ZarPhaseA2Store {
  ZarPhaseA2Store({
    required ZarDomainRepository repository,
    required ZarLegacyPresentationBridge bridge,
    DateTime Function()? clock,
  }) : _repository = repository,
       _bridge = bridge,
       _clock = clock ?? DateTime.now;

  final ZarDomainRepository _repository;
  final ZarLegacyPresentationBridge _bridge;
  final DateTime Function() _clock;

  final Map<String, ZarPerson> _domainPeople = {};
  final Map<String, ZarSettlement> _domainSettlements = {};
  final Map<String, ZarDeal> _domainDeals = {};

  bool _loading = false;
  Object? _lastError;

  bool get loading => _loading;
  Object? get lastError => _lastError;
  List<ZarPerson> get domainPeople => List.unmodifiable(_domainPeople.values);
  List<ZarSettlement> get settlements =>
      List.unmodifiable(_domainSettlements.values);
  List<ZarDeal> get deals => List.unmodifiable(_domainDeals.values);

  List<AppPerson> get people =>
      List.unmodifiable(_domainPeople.values.map(_bridge.personToUi));
  List<AppRecord> get records {
    final result = <AppRecord>[
      ..._domainSettlements.values.map(_bridge.settlementToUi),
      ..._domainDeals.values.map(_bridge.dealToUi),
    ]..sort(_compareRecordDescending);
    return List.unmodifiable(result);
  }

  List<AppPerson> get activePeople => _domainPeople.values
      .where((item) => !item.archived)
      .map(_bridge.personToUi)
      .toList(growable: false);
  List<AppPerson> get archivedPeople => _domainPeople.values
      .where((item) => item.archived)
      .map(_bridge.personToUi)
      .toList(growable: false);

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
        ..addEntries(
          [...active, ...archived].map((item) => MapEntry(item.id, item)),
        );
      _domainSettlements
        ..clear()
        ..addEntries(settlements.map((item) => MapEntry(item.id, item)));
      _domainDeals
        ..clear()
        ..addEntries(deals.map((item) => MapEntry(item.id, item)));
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  String personName(String personId) {
    return _domainPeople[personId]?.displayName ?? 'نامشخص';
  }

  int openCountFor(String personId) => _domainSettlements.values
      .where(
        (item) =>
            item.personId == personId &&
            item.status == ZarSettlementStatus.open,
      )
      .length;

  Future<void> savePerson(AppPerson person) async {
    final domain = _bridge.personFromUi(
      person,
      existing: _domainPeople[person.id],
      now: _clock(),
    );
    await _repository.savePerson(domain);
    _domainPeople[domain.id] = domain;
  }

  Future<void> archivePerson(AppPerson person) async {
    final existing =
        _domainPeople[person.id] ?? _bridge.personFromUi(person, now: _clock());
    await _repository.archivePerson(existing);
    final archived = _bridge.personFromUi(
      person.copyWith(archived: true),
      existing: existing,
      now: _clock(),
    );
    _domainPeople[archived.id] = archived;
  }

  Future<void> restorePerson(AppPerson person) async {
    final existing =
        _domainPeople[person.id] ?? _bridge.personFromUi(person, now: _clock());
    await _repository.restorePerson(existing);
    final restored = _bridge.personFromUi(
      person.copyWith(archived: false),
      existing: existing,
      now: _clock(),
    );
    _domainPeople[restored.id] = restored;
  }

  Future<void> saveRecord(
    AppRecord record, {
    String auditAction = 'edit',
    ZarReminderPlan? reminderPlan,
  }) async {
    if (record.type == RecordType.settlement) {
      final existing = _domainSettlements[record.id];
      var domain = _bridge.settlementFromUi(
        record,
        existing: existing,
        now: _clock(),
      );
      if (reminderPlan != null) {
        domain = _copySettlement(
          domain,
          reminderPlan: reminderPlan,
          updatedAt: _clock().toUtc(),
        );
      }
      await _repository.saveSettlement(domain, auditAction: auditAction);
      _domainSettlements[domain.id] = domain;
    } else {
      final domain = _bridge.dealFromUi(
        record,
        existing: _domainDeals[record.id],
        now: _clock(),
      );
      await _repository.saveDeal(domain, auditAction: auditAction);
      _domainDeals[domain.id] = domain;
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
    final updated = _copySettlement(
      existing,
      reminderPlan: reminderPlan,
      updatedAt: _clock().toUtc(),
    );
    await _repository.saveSettlement(updated, auditAction: auditAction);
    _domainSettlements[updated.id] = updated;
  }

  Future<void> completeSettlement(AppRecord record) => saveRecord(
    record.copyWith(status: SettlementStatus.completed),
    auditAction: 'complete',
  );

  Future<void> cancelSettlement(AppRecord record) => saveRecord(
    record.copyWith(status: SettlementStatus.cancelled),
    auditAction: 'cancel',
  );

  Future<void> rescheduleSettlement(AppRecord record) =>
      saveRecord(record, auditAction: 'reschedule');

  AppPerson? personById(String id) {
    final person = _domainPeople[id];
    return person == null ? null : _bridge.personToUi(person);
  }

  AppRecord? recordById(String id) {
    final settlement = _domainSettlements[id];
    if (settlement != null) return _bridge.settlementToUi(settlement);
    final deal = _domainDeals[id];
    return deal == null ? null : _bridge.dealToUi(deal);
  }

  ZarSettlement? settlementById(String id) => _domainSettlements[id];
  ZarDeal? dealById(String id) => _domainDeals[id];

  ZarSettlement _copySettlement(
    ZarSettlement source, {
    ZarReminderPlan? reminderPlan,
    DateTime? updatedAt,
  }) => ZarSettlement(
    id: source.id,
    businessId: source.businessId,
    dealId: source.dealId,
    personId: source.personId,
    direction: source.direction,
    amount: source.amount,
    scheduledAt: source.scheduledAt,
    hasTime: source.hasTime,
    status: source.status,
    reminderPlan: reminderPlan ?? source.reminderPlan,
    completedAt: source.completedAt,
    completedBy: source.completedBy,
    note: source.note,
    createdBy: source.createdBy,
    createdAt: source.createdAt,
    updatedAt: updatedAt ?? source.updatedAt,
  );

  int _compareRecordDescending(AppRecord a, AppRecord b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    final aMinutes = (a.time?.hour ?? 0) * 60 + (a.time?.minute ?? 0);
    final bMinutes = (b.time?.hour ?? 0) * 60 + (b.time?.minute ?? 0);
    return bMinutes.compareTo(aMinutes);
  }
}
