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

  static const _people = 'zar_people';
  static const _deals = 'zar_deals';
  static const _settlements = 'zar_settlements';
  static const _coinTypes = 'zar_coin_types';
  static const _currencyTypes = 'zar_currency_types';
  static const _allocations = 'zar_allocations';
  static const _cash = 'zar_cash_entries';

  String get _workspaceFilter => "workspace='$_workspaceId'";

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
    await _client.createRecord(_cash, {'id': entry.id, ..._row(entry.toMap())});
  }

  Map<String, Object?> _row(Object payload) => {
    'workspace': _workspaceId,
    'data': payload,
  };

  Future<void> _upsert(
    String collection, {
    required String id,
    required Map<String, Object?> body,
  }) async {
    try {
      await _client.updateRecord(collection, id: id, body: body);
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 404) {
        await _client.createRecord(collection, {...body, 'id': id});
        return;
      }
      rethrow;
    }
  }

  @override
  Future<ZarDomainSnapshot> loadCompleteSnapshot() async {
    final results = await Future.wait([
      _client.listRecords(_people, filter: _workspaceFilter),
      _client.listRecords(_deals, filter: _workspaceFilter),
      _client.listRecords(_settlements, filter: _workspaceFilter),
      _client.listRecords(_coinTypes, filter: _workspaceFilter),
      _client.listRecords(_currencyTypes, filter: _workspaceFilter),
      _client.listRecords(_allocations, filter: _workspaceFilter),
      _client.listRecords(_cash, filter: _workspaceFilter),
    ]);
    return ZarDomainSnapshot(
      cashEntries: results[6]
          .map((row) => ZarCashEntry.fromMap(_data(row)))
          .toList(),
      people: results[0]
          .map((row) => _codec.personFromRecord(_data(row)))
          .toList(growable: false),
      deals: results[1]
          .map((row) => _codec.dealFromRecord(_data(row), _businessId))
          .toList(growable: false),
      settlements: results[2]
          .map((row) => _codec.settlementFromRecord(_data(row), _businessId))
          .toList(growable: false),
      coinTypes: results[3]
          .map((row) => ZarCoinType.fromMap(_data(row)))
          .toList(growable: false),
      currencyTypes: results[4]
          .map((row) => ZarCurrencyType.fromMap(_data(row)))
          .toList(growable: false),
      paymentAllocations: results[5]
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

  static const _batchChunk = 400;

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
      _upsert(_people, id: person.id, body: _row(_codec.personRecord(person)));

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) =>
      _upsert(_deals, id: deal.id, body: _row(_codec.dealRecord(deal)));

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) => _upsert(
    _settlements,
    id: settlement.id,
    body: _row(_codec.settlementRecord(settlement)),
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
      _upsert(_coinTypes, id: coinType.id, body: _row(coinType.toMap()));

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
  Future<void> saveCurrencyType(ZarCurrencyType currencyType) => _upsert(
    _currencyTypes,
    id: currencyType.id,
    body: _row(currencyType.toMap()),
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
    // Replace this movement's rows: delete existing + create the new set.
    final existing = await _client.listRecords(
      _allocations,
      filter:
          "(data.settlementId='$settlementId' && workspace='$_workspaceId')",
    );
    final deletes = [
      for (final row in existing)
        (
          method: 'DELETE',
          url: '/api/collections/$_allocations/records/${row['id']! as String}',
          body: null,
        ),
    ];
    final creates = [
      for (final allocation in allocations)
        (
          method: 'POST',
          url: '/api/collections/$_allocations/records',
          body: {'id': _allocationId(allocation), ..._row(allocation.toMap())},
        ),
    ];
    final ops = [...deletes, ...creates];
    for (var i = 0; i < ops.length; i += _batchChunk) {
      await _client.batch(
        ops.sublist(
          i,
          (i + _batchChunk) < ops.length ? i + _batchChunk : ops.length,
        ),
      );
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
