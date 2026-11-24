import 'dart:convert';
import 'dart:math';

import '../../domain/zar_domain_models.dart';
import '../../domain/zar_payment_allocation.dart';
import '../../domain/zar_cash_entry.dart';
import '../zar_domain_backup_codec.dart';
import '../zar_domain_repository.dart';
import 'zar_pocketbase_client.dart';

/// PocketBase-backed repository implementing the same boundary the local
/// Drift repository satisfies, so the live shell can run against a cheap
/// self-hosted server without any UI or store changes.
///
/// Every collection row is `{workspace, data}` where `data` holds the tested
/// V8 backup per-entity JSON. Whole-snapshot loads replace the local store in
/// one go; writes upsert single records. Destructive restore uses a dedicated
/// authenticated compare-and-swap route so all seven collections (including
/// append-only cash) and the idempotency receipt share one server transaction.
class ZarPocketBaseRepository
    implements
        ZarDomainRepository,
        ZarWorkspaceEpochSource,
        ZarCoinCatalogRepository,
        ZarCurrencyCatalogRepository,
        ZarPaymentAllocationRepository,
        ZarCashRepository {
  ZarPocketBaseRepository({
    required ZarPocketBaseClient client,
    required String workspaceId,
    required String businessId,
  }) : _client = client,
       _workspaceId = workspaceId,
       _businessId = businessId,
       _codec = const ZarDomainBackupCodec();

  final ZarPocketBaseClient _client;
  final String _workspaceId;
  final String _businessId;
  final ZarDomainBackupCodec _codec;

  /// Server-issued revisions for people/deals/settlements CAS upserts.
  /// Keyed as `collection:id`. Missing means create (`expectedRevision=0`).
  final Map<String, int> _revisions = <String, int>{};

  int? _lastKnownEpoch;

  @override
  int? get lastKnownEpoch => _lastKnownEpoch;

  static const _people = 'zar_people';
  static const _deals = 'zar_deals';
  static const _settlements = 'zar_settlements';
  static const _coinTypes = 'zar_coin_types';
  static const _currencyTypes = 'zar_currency_types';
  static const _allocations = 'zar_allocations';
  static const _cash = 'zar_cash_entries';
  static const _casCollections = {
    _people,
    _deals,
    _settlements,
    _coinTypes,
    _currencyTypes,
  };

  @override
  Future<void> appendCashEntry(ZarCashEntry entry) async {
    final snapshot = await loadCompleteSnapshot();
    final existing = snapshot.cashEntries.where((e) => e.id == entry.id);
    if (existing.isNotEmpty) {
      if (jsonEncode(existing.single.toMap()) != jsonEncode(entry.toMap())) {
        throw StateError('Cash entries are immutable.');
      }
      return;
    }
    validateCashEntries(
      entries: [...snapshot.cashEntries, entry],
      deals: snapshot.deals,
      settlements: snapshot.settlements,
    );
    try {
      await _client.requestJson(
        'POST',
        '/api/zar/write/cash/append',
        body: {
          'workspaceId': _workspaceId,
          'id': entry.id,
          'idempotencyKey': _newIdempotencyKey(),
          'data': entry.toMap(),
        },
      );
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 409) {
        final details = _parseWriteConflictMessage(error.message);
        final code = details?['code'];
        if (code == 'idempotency_payload_mismatch') {
          throw ZarCloudWriteConflictException.idempotencyMismatch(
            collection: _cash,
            recordId: entry.id,
          );
        }
        throw ZarCloudWriteConflictException(
          code: code is String ? code : 'cash_entry_immutable',
          collection: _cash,
          recordId: entry.id,
          message:
              'این ردیف صندوق روی سرور قابل تغییر نیست یا قبلاً با '
              'محتوای دیگری ثبت شده است.',
        );
      }
      rethrow;
    }
  }

  String _revisionKey(String collection, String id) => '$collection:$id';

  int _expectedRevision(String collection, String id) =>
      _revisions[_revisionKey(collection, id)] ?? 0;

  void _rememberRevision(String collection, String id, int revision) {
    _revisions[_revisionKey(collection, id)] = revision;
  }

  void _ingestRevisions(String collection, List<Map<String, Object?>> rows) {
    for (final row in rows) {
      final id = row['id'];
      if (id is! String || id.isEmpty) continue;
      final raw = row['revision'];
      final revision = switch (raw) {
        int value => value,
        num value => value.toInt(),
        _ => 1,
      };
      _rememberRevision(collection, id, revision < 1 ? 1 : revision);
    }
  }

  static String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Map<String, Object?>? _parseWriteConflictMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;
    // PocketBase appends a trailing period to ApiError messages.
    final candidates = <String>{
      trimmed,
      if (trimmed.endsWith('.')) trimmed.substring(0, trimmed.length - 1),
    };
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) {
          return Map<String, Object?>.from(decoded);
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// CAS + idempotent upsert for people/deals/settlements/coin/currency.
  Future<void> _casUpsert(
    String collection, {
    required String id,
    required Map<String, Object?> data,
  }) async {
    assert(_casCollections.contains(collection));
    final expectedRevision = _expectedRevision(collection, id);
    final idempotencyKey = _newIdempotencyKey();
    try {
      final result = await _client.requestJson(
        'POST',
        '/api/zar/write/upsert',
        body: {
          'collection': collection,
          'id': id,
          'workspaceId': _workspaceId,
          'expectedRevision': expectedRevision,
          'idempotencyKey': idempotencyKey,
          'data': data,
        },
      );
      final revision = result['revision'];
      if (revision is int) {
        _rememberRevision(collection, id, revision);
      } else if (revision is num) {
        _rememberRevision(collection, id, revision.toInt());
      }
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 409) {
        final details = _parseWriteConflictMessage(error.message);
        final code = details?['code'];
        final current = details?['currentRevision'];
        final currentRevision = switch (current) {
          int value => value,
          num value => value.toInt(),
          _ => null,
        };
        if (code == 'idempotency_payload_mismatch') {
          throw ZarCloudWriteConflictException.idempotencyMismatch(
            collection: collection,
            recordId: id,
          );
        }
        if (code == 'lifecycle_locked') {
          throw ZarCloudWriteConflictException.lifecycleLocked(
            collection: collection,
            recordId: id,
          );
        }
        if (code == 'terminal_field_locked') {
          throw ZarCloudWriteConflictException.terminalFieldLocked(
            collection: collection,
            recordId: id,
          );
        }
        throw ZarCloudWriteConflictException.staleRevision(
          collection: collection,
          recordId: id,
          currentRevision: currentRevision,
        );
      }
      rethrow;
    }
  }

  @override
  Future<int?> peekRemoteEpoch() async {
    final row = await _client.getRecord(
      'zar_workspaces',
      id: _workspaceId,
    );
    return _parseEpoch(row['epoch']);
  }

  static int? _parseEpoch(Object? raw) {
    if (raw == null) return 0;
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is num) {
      final value = raw.toInt();
      return value < 0 ? 0 : value;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final value = int.tryParse(raw.trim());
      if (value == null || value < 0) return 0;
      return value;
    }
    return 0;
  }

  @override
  Future<ZarDomainSnapshot> loadCompleteSnapshot() async {
    // Single epoch-fenced route so concurrent writes cannot mix collections
    // across seven independent list GETs (ZAR-DATA-006).
    final payload = await _client.requestJson('GET', '/api/zar/read/snapshot');
    if (payload['workspaceId'] != _workspaceId) {
      throw const ZarPocketBaseProtocolException(
        'Snapshot workspace does not match the selected workspace.',
      );
    }
    _lastKnownEpoch = _parseEpoch(payload['epoch']);
    List<Map<String, Object?>> rows(String key) {
      final raw = payload[key];
      if (raw is! List) {
        throw ZarPocketBaseProtocolException(
          'Snapshot is missing collection "$key".',
        );
      }
      return [
        for (final item in raw) Map<String, Object?>.from(item! as Map),
      ];
    }

    final people = rows('people');
    final deals = rows('deals');
    final settlements = rows('settlements');
    final coinTypes = rows('coinTypes');
    final currencyTypes = rows('currencyTypes');
    final allocations = rows('allocations');
    final cashEntries = rows('cashEntries');
    _ingestRevisions(_people, people);
    _ingestRevisions(_deals, deals);
    _ingestRevisions(_settlements, settlements);
    _ingestRevisions(_coinTypes, coinTypes);
    _ingestRevisions(_currencyTypes, currencyTypes);
    return ZarDomainSnapshot(
      cashEntries: cashEntries
          .map((row) => ZarCashEntry.fromMap(_data(row)))
          .toList(),
      people: people
          .map((row) => _codec.personFromRecord(_data(row)))
          .toList(growable: false),
      deals: deals
          .map((row) => _codec.dealFromRecord(_data(row), _businessId))
          .toList(growable: false),
      settlements: settlements
          .map((row) => _codec.settlementFromRecord(_data(row), _businessId))
          .toList(growable: false),
      coinTypes: coinTypes
          .map((row) => ZarCoinType.fromMap(_data(row)))
          .toList(growable: false),
      currencyTypes: currencyTypes
          .map((row) => ZarCurrencyType.fromMap(_data(row)))
          .toList(growable: false),
      paymentAllocations: allocations
          .map((row) => ZarPaymentAllocation.fromMap(_data(row)))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _data(Map<String, Object?> row) {
    final data = row['data'];
    if (data is Map) return Map<String, Object?>.from(data);
    if (data is String && data.isNotEmpty) {
      return Map<String, Object?>.from(jsonDecode(data) as Map);
    }
    throw const FormatException('Invalid ZAR+ cloud record payload.');
  }

  @override
  Future<void> replaceCompleteSnapshot(
    ZarDomainSnapshot snapshot, {
    String? confirmationSecret,
  }) async {
    validateCashEntries(
      entries: snapshot.cashEntries,
      deals: snapshot.deals,
      settlements: snapshot.settlements,
    );
    validateZarPaymentAllocations(
      deals: snapshot.deals,
      settlements: snapshot.settlements,
      allocations: snapshot.paymentAllocations,
    );
    if (confirmationSecret == null || confirmationSecret.isEmpty) {
      throw const ZarCloudRestoreException.reauthenticationRequired();
    }
    try {
      final state = await _client.requestJson('GET', '/api/zar/restore/state');
      final expectedStateHash = state['stateHash'];
      if (state['protocolVersion'] != _restoreProtocolVersion ||
          state['workspaceId'] != _workspaceId ||
          expectedStateHash is! String ||
          !_restoreHashPattern.hasMatch(expectedStateHash)) {
        throw const ZarCloudRestoreException.invalidReceipt();
      }

      final requestId = _newRestoreRequestId();
      final body = <String, Object?>{
        'protocolVersion': _restoreProtocolVersion,
        'requestId': requestId,
        'businessId': _businessId,
        'confirmationPassword': confirmationSecret,
        'expectedStateHash': expectedStateHash,
        'snapshot': _restoreSnapshot(snapshot),
      };

      Future<Map<String, Object?>> commit() =>
          _client.requestJson('POST', '/api/zar/restore/commit', body: body);

      late Map<String, Object?> receipt;
      try {
        receipt = await commit();
      } catch (error) {
        if (!_isAmbiguousCommitResult(error)) rethrow;
        // A lost response is ambiguous: the first call may already be durable.
        // Reusing its id makes the retry return the original server receipt.
        try {
          receipt = await commit();
          _verifyRestoreReceipt(
            receipt,
            requestId: requestId,
            expectedStateHash: expectedStateHash,
            expectedCounts: _restoreCounts(snapshot),
          );
          return;
        } catch (_) {
          // Once the first result is ambiguous, a later 4xx, transport error,
          // protocol error, or unverifiable receipt cannot prove that no
          // commit occurred. Never downgrade that state to a definite failure.
          throw const ZarCloudRestoreException.outcomeUnknown();
        }
      }
      _verifyRestoreReceipt(
        receipt,
        requestId: requestId,
        expectedStateHash: expectedStateHash,
        expectedCounts: _restoreCounts(snapshot),
      );
      // Transactional restore rewrites rows at revision 1; drop stale cache.
      _revisions.clear();
      for (final person in snapshot.people) {
        _rememberRevision(_people, person.id, 1);
      }
      for (final deal in snapshot.deals) {
        _rememberRevision(_deals, deal.id, 1);
      }
      for (final settlement in snapshot.settlements) {
        _rememberRevision(_settlements, settlement.id, 1);
      }
      for (final coinType in snapshot.coinTypes) {
        _rememberRevision(_coinTypes, coinType.id, 1);
      }
      for (final currencyType in snapshot.currencyTypes) {
        _rememberRevision(_currencyTypes, currencyType.id, 1);
      }
    } on ZarPocketBaseException catch (error) {
      throw switch (error.statusCode) {
        403 => const ZarCloudRestoreException.sharedWorkspace(),
        404 => const ZarCloudRestoreException.serverRestoreUnavailable(),
        409 => const ZarCloudRestoreException.concurrentCloudChange(),
        413 => const ZarCloudRestoreException.restoreTooLarge(),
        428 => const ZarCloudRestoreException.reauthenticationRequired(),
        _ => const ZarCloudRestoreException.serverRejected(),
      };
    }
  }

  static const _restoreProtocolVersion = 1;
  static final _restoreHashPattern = RegExp(r'^[a-f0-9]{64}$');

  static bool _isAmbiguousCommitResult(Object error) =>
      error is ZarPocketBaseTransportException ||
      error is ZarPocketBaseProtocolException ||
      (error is ZarPocketBaseException && error.statusCode >= 500);

  static String _newRestoreRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, Object?> _restoreRow(String id, Map<String, Object?> data) => {
    'id': id,
    'data': data,
  };

  Map<String, Object?> _restoreSnapshot(ZarDomainSnapshot snapshot) => {
    'people': [
      for (final person in snapshot.people)
        _restoreRow(person.id, _codec.personRecord(person)),
    ],
    'deals': [
      for (final deal in snapshot.deals)
        _restoreRow(deal.id, _codec.dealRecord(deal)),
    ],
    'settlements': [
      for (final settlement in snapshot.settlements)
        _restoreRow(settlement.id, _codec.settlementRecord(settlement)),
    ],
    'coinTypes': [
      for (final type in snapshot.coinTypes) _restoreRow(type.id, type.toMap()),
    ],
    'currencyTypes': [
      for (final type in snapshot.currencyTypes)
        _restoreRow(type.id, type.toMap()),
    ],
    'paymentAllocations': [
      for (final allocation in snapshot.paymentAllocations)
        _restoreRow(_allocationId(allocation), allocation.toMap()),
    ],
    'cashEntries': [
      for (final entry in snapshot.cashEntries)
        _restoreRow(entry.id, entry.toMap()),
    ],
  };

  static Map<String, int> _restoreCounts(ZarDomainSnapshot snapshot) {
    final counts = <String, int>{
      'people': snapshot.people.length,
      'deals': snapshot.deals.length,
      'settlements': snapshot.settlements.length,
      'coinTypes': snapshot.coinTypes.length,
      'currencyTypes': snapshot.currencyTypes.length,
      'paymentAllocations': snapshot.paymentAllocations.length,
      'cashEntries': snapshot.cashEntries.length,
    };
    counts['total'] = counts.values.fold(0, (total, count) => total + count);
    return counts;
  }

  void _verifyRestoreReceipt(
    Map<String, Object?> receipt, {
    required String requestId,
    required String expectedStateHash,
    required Map<String, int> expectedCounts,
  }) {
    final snapshotHash = receipt['snapshotHash'];
    final counts = receipt['counts'];
    final committedAt = receipt['committedAt'];
    if (receipt['protocolVersion'] != _restoreProtocolVersion ||
        receipt['requestId'] != requestId ||
        receipt['workspaceId'] != _workspaceId ||
        receipt['beforeHash'] != expectedStateHash ||
        snapshotHash is! String ||
        !_restoreHashPattern.hasMatch(snapshotHash) ||
        receipt['afterHash'] != snapshotHash ||
        receipt['replayed'] is! bool ||
        counts is! Map ||
        counts.length != expectedCounts.length ||
        committedAt is! String ||
        DateTime.tryParse(committedAt) == null ||
        expectedCounts.entries.any(
          (entry) => counts[entry.key] != entry.value,
        )) {
      throw const ZarCloudRestoreException.invalidReceipt();
    }
  }

  String _allocationId(ZarPaymentAllocation allocation) =>
      'alloc-${allocation.settlementId}-${allocation.targetType.name}-${allocation.targetId}';

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) async =>
      (await loadCompleteSnapshot()).people
          .where((item) => !item.archived)
          .take(limit)
          .toList(growable: false);

  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) async =>
      (await loadCompleteSnapshot()).people
          .where((item) => item.archived)
          .take(limit)
          .toList(growable: false);

  @override
  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  }) async => (await loadCompleteSnapshot()).settlements
      .where((item) => item.isOpen)
      .where((item) => !item.scheduledAt.isBefore(from))
      .where((item) => item.scheduledAt.isBefore(through))
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) async => (await loadCompleteSnapshot()).settlements
      .where((item) => item.isOpen && item.scheduledAt.isBefore(now))
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 250}) async {
    final result = (await loadCompleteSnapshot()).settlements.toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarDeal>> loadRecentDeals({int limit = 250}) async {
    final result = (await loadCompleteSnapshot()).deals.toList()
      ..sort((a, b) => b.dealAt.compareTo(a.dealAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  }) async {
    final result =
        (await loadCompleteSnapshot()).settlements
            .where((item) => item.personId == personId)
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  }) async {
    final result =
        (await loadCompleteSnapshot()).deals
            .where((item) => item.personId == personId)
            .toList()
          ..sort((a, b) => b.dealAt.compareTo(a.dealAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) =>
      _casUpsert(
        _people,
        id: person.id,
        data: _codec.personRecord(person),
      );

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) =>
      _casUpsert(_deals, id: deal.id, data: _codec.dealRecord(deal));

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) => _casUpsert(
    _settlements,
    id: settlement.id,
    data: _codec.settlementRecord(settlement),
  );

  @override
  Future<void> archivePerson(ZarPerson person) =>
      savePerson(_copyPerson(person, archived: true), auditAction: 'archive');

  @override
  Future<void> restorePerson(ZarPerson person) =>
      savePerson(_copyPerson(person, archived: false), auditAction: 'restore');

  @override
  Future<List<ZarCoinType>> loadCoinTypes({
    bool includeArchived = false,
  }) async => (await loadCompleteSnapshot()).coinTypes
      .where((item) => includeArchived || !item.archived)
      .toList(growable: false);

  @override
  Future<void> saveCoinType(ZarCoinType coinType) =>
      _casUpsert(_coinTypes, id: coinType.id, data: coinType.toMap());

  @override
  Future<void> archiveCoinType(ZarCoinType coinType) => saveCoinType(
    coinType.copyWith(archived: true, updatedAt: DateTime.now().toUtc()),
  );

  @override
  Future<void> restoreCoinType(ZarCoinType coinType) => saveCoinType(
    coinType.copyWith(archived: false, updatedAt: DateTime.now().toUtc()),
  );

  @override
  Future<List<ZarCurrencyType>> loadCurrencyTypes({
    bool includeArchived = false,
  }) async => (await loadCompleteSnapshot()).currencyTypes
      .where((item) => includeArchived || !item.archived)
      .toList(growable: false);

  @override
  Future<void> saveCurrencyType(ZarCurrencyType currencyType) => _casUpsert(
    _currencyTypes,
    id: currencyType.id,
    data: currencyType.toMap(),
  );

  @override
  Future<void> archiveCurrencyType(ZarCurrencyType currencyType) =>
      saveCurrencyType(
        currencyType.copyWith(
          archived: true,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> restoreCurrencyType(ZarCurrencyType currencyType) =>
      saveCurrencyType(
        currencyType.copyWith(
          archived: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> savePaymentAllocations(
    String settlementId,
    List<ZarPaymentAllocation> allocations,
  ) async {
    if (allocations.any((row) => row.settlementId != settlementId)) {
      throw const FormatException('Allocation source mismatch.');
    }
    final existing = await _client.listRecords(
      _allocations,
      filter:
          "(data.settlementId='$settlementId' && workspace='$_workspaceId')",
    );
    final expectedBefore = [
      for (final row in existing)
        {
          'id': row['id'],
          'data': _data(row),
        },
    ]..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

    try {
      await _client.requestJson(
        'POST',
        '/api/zar/write/allocations/replace',
        body: {
          'workspaceId': _workspaceId,
          'settlementId': settlementId,
          'idempotencyKey': _newIdempotencyKey(),
          'expectedBefore': expectedBefore,
          'allocations': [
            for (final allocation in allocations) allocation.toMap(),
          ],
        },
      );
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 409) {
        final details = _parseWriteConflictMessage(error.message);
        final code = details?['code'];
        if (code == 'idempotency_payload_mismatch') {
          throw ZarCloudWriteConflictException.idempotencyMismatch(
            collection: _allocations,
            recordId: settlementId,
          );
        }
        throw ZarCloudWriteConflictException(
          code: code is String ? code : 'stale_allocation_set',
          collection: _allocations,
          recordId: settlementId,
          message:
              'تخصیص‌های این تعهد روی سرور تغییر کرده است. '
              'هیچ تغییری ذخیره نشد. صفحه را تازه کنید و دوباره ثبت کنید.',
        );
      }
      rethrow;
    }
  }

  ZarPerson _copyPerson(ZarPerson person, {required bool archived}) =>
      ZarPerson(
        id: person.id,
        displayName: person.displayName,
        phone: person.phone,
        note: person.note,
        archived: archived,
        createdAt: person.createdAt,
        updatedAt: DateTime.now().toUtc(),
        createdBy: person.createdBy,
      );
}

typedef ZarDomainRecord = ({String id, Map<String, Object?> payload});
