import 'dart:convert';


import '../../domain/zar_domain_models.dart';
import '../../domain/zar_payment_allocation.dart';
import '../zar_domain_backup_codec.dart';
import '../zar_domain_repository.dart';
import 'zar_pocketbase_client.dart';

/// PocketBase-backed repository implementing the same boundary the local
/// Drift repository satisfies, so the live shell can run against a cheap
/// self-hosted server without any UI or store changes.
///
/// Every collection row is `{workspace, data}` where `data` holds the tested
/// V7 backup per-entity JSON. Whole-snapshot loads replace the local store in
/// one go; writes upsert single records; restore uses the PocketBase batch
/// endpoint per collection (transactional within each batch).
class ZarPocketBaseRepository
    implements
        ZarDomainRepository,
        ZarCoinCatalogRepository,
        ZarCurrencyCatalogRepository,
        ZarPaymentAllocationRepository {
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

  Map<String, Object?> _row(Object payload) =>
      {'workspace': _workspaceId, 'data': payload};

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
      _client.listRecords(_people),
      _client.listRecords(_deals),
      _client.listRecords(_settlements),
      _client.listRecords(_coinTypes),
      _client.listRecords(_currencyTypes),
      _client.listRecords(_allocations),
    ]);
    return ZarDomainSnapshot(
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
  Future<void> replaceCompleteSnapshot(ZarDomainSnapshot snapshot) async {
    validateZarPaymentAllocations(
      deals: snapshot.deals,
      settlements: snapshot.settlements,
      allocations: snapshot.paymentAllocations,
    );
    // One batch per collection keeps every collection internally transactional
    // (delete-then-create inside the same server-side transaction).
    Future<void> replaceAll(
      String collection,
      List<ZarDomainRecord> records,
    ) async {
      final existing = await _client.listRecords(collection);
      final deletes = [
        for (final row in existing)
          (
            method: 'DELETE',
            url: '/api/collections/$collection/records/${row['id']! as String}',
            body: null,
          ),
      ];
      if (deletes.isNotEmpty) await _client.batch(deletes.toList());
      final creates = [
        for (final record in records)
          (
            method: 'POST',
            url: '/api/collections/$collection/records',
            body: {'id': record.id, ..._row(record.payload)},
          ),
      ];
      for (var i = 0; i < creates.length; i += _batchChunk) {
        await _client.batch(creates.sublist(i, (i + _batchChunk) < creates.length ? i + _batchChunk : creates.length));
      }
    }

    await replaceAll(
      _people,
      [
        for (final person in snapshot.people)
          (id: person.id, payload: _codec.personRecord(person)),
      ],
    );
    await replaceAll(
      _deals,
      [
        for (final deal in snapshot.deals)
          (id: deal.id, payload: _codec.dealRecord(deal)),
      ],
    );
    await replaceAll(
      _settlements,
      [
        for (final settlement in snapshot.settlements)
          (id: settlement.id, payload: _codec.settlementRecord(settlement)),
      ],
    );
    await replaceAll(
      _coinTypes,
      [
        for (final type in snapshot.coinTypes)
          (id: type.id, payload: type.toMap()),
      ],
    );
    await replaceAll(
      _currencyTypes,
      [
        for (final type in snapshot.currencyTypes)
          (id: type.id, payload: type.toMap()),
      ],
    );
    await replaceAll(
      _allocations,
      [
        for (final allocation in snapshot.paymentAllocations)
          (id: _allocationId(allocation), payload: allocation.toMap()),
      ],
    );
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
  }) async =>
      (await loadCompleteSnapshot())
          .settlements
          .where((item) => item.isOpen)
          .where((item) => !item.scheduledAt.isBefore(from))
          .where((item) => item.scheduledAt.isBefore(through))
          .take(limit)
          .toList(growable: false);

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) async =>
      (await loadCompleteSnapshot())
          .settlements
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
    final result = (await loadCompleteSnapshot())
        .settlements
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
    final result = (await loadCompleteSnapshot())
        .deals
        .where((item) => item.personId == personId)
        .toList()
      ..sort((a, b) => b.dealAt.compareTo(a.dealAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<void> savePerson(
    ZarPerson person, {
    String auditAction = 'edit',
  }) => _upsert(_people, id: person.id, body: _row(_codec.personRecord(person)));

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
  Future<void> archivePerson(ZarPerson person) => savePerson(
    _copyPerson(person, archived: true),
    auditAction: 'archive',
  );

  @override
  Future<void> restorePerson(ZarPerson person) => savePerson(
    _copyPerson(person, archived: false),
    auditAction: 'restore',
  );

  @override
  Future<List<ZarCoinType>> loadCoinTypes({
    bool includeArchived = false,
  }) async => (await loadCompleteSnapshot())
      .coinTypes
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
  }) async => (await loadCompleteSnapshot())
      .currencyTypes
      .where((item) => includeArchived || !item.archived)
      .toList(growable: false);

  @override
  Future<void> saveCurrencyType(ZarCurrencyType currencyType) =>
      _upsert(
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
          url:
              '/api/collections/$_allocations/records/${row['id']! as String}',
          body: null,
        ),
    ];
    final creates = [
      for (final allocation in allocations)
        (
          method: 'POST',
          url: '/api/collections/$_allocations/records',
          body: {
            'id': _allocationId(allocation),
            ..._row(allocation.toMap()),
          },
        ),
    ];
    final ops = [...deletes, ...creates];
    for (var i = 0; i < ops.length; i += _batchChunk) {
      await _client.batch(
        ops.sublist(i, (i + _batchChunk) < ops.length ? i + _batchChunk : ops.length),
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
