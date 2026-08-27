import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/zar_domain_models.dart';
import '../zar_domain_repository.dart';
import 'zar_firestore_mapper.dart';

class ZarFirestoreRepository implements ZarDomainRepository {
  ZarFirestoreRepository({
    required FirebaseFirestore firestore,
    required this.businessId,
    required this.userId,
    ZarFirestoreMapper mapper = const ZarFirestoreMapper(),
  })  : _firestore = firestore,
        _mapper = mapper;

  final FirebaseFirestore _firestore;
  final ZarFirestoreMapper _mapper;
  final String businessId;
  final String userId;

  DocumentReference<Map<String, dynamic>> get _business =>
      _firestore.collection('businesses').doc(businessId);

  CollectionReference<Map<String, dynamic>> get _people =>
      _business.collection('people');

  CollectionReference<Map<String, dynamic>> get _deals =>
      _business.collection('deals');

  CollectionReference<Map<String, dynamic>> get _settlements =>
      _business.collection('settlements');

  CollectionReference<Map<String, dynamic>> get _audit =>
      _business.collection('auditLogs');

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) async {
    final snapshot = await _people
        .where('archived', isEqualTo: false)
        .orderBy('normalizedName')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.personFromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) async {
    final snapshot = await _people
        .where('archived', isEqualTo: true)
        .orderBy('normalizedName')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.personFromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  }) async {
    final snapshot = await _settlements
        .where('status', isEqualTo: ZarSettlementStatus.open.name)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(through.toUtc()))
        .orderBy('scheduledAt')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.settlementFromMap(
              id: doc.id,
              businessId: businessId,
              map: doc.data(),
            ))
        .toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) async {
    final snapshot = await _settlements
        .where('status', isEqualTo: ZarSettlementStatus.open.name)
        .where('scheduledAt', isLessThan: Timestamp.fromDate(now.toUtc()))
        .orderBy('scheduledAt')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.settlementFromMap(
              id: doc.id,
              businessId: businessId,
              map: doc.data(),
            ))
        .toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  }) async {
    final snapshot = await _settlements
        .where('personId', isEqualTo: personId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.settlementFromMap(
              id: doc.id,
              businessId: businessId,
              map: doc.data(),
            ))
        .toList(growable: false);
  }

  @override
  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  }) async {
    final snapshot = await _deals
        .where('personId', isEqualTo: personId)
        .orderBy('dealAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _mapper.dealFromMap(
              id: doc.id,
              businessId: businessId,
              map: doc.data(),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) async {
    final ref = _people.doc(person.id);
    final before = await ref.get();
    final batch = _firestore.batch();
    batch.set(ref, _mapper.personToMap(person), SetOptions(merge: true));
    _appendAuditToBatch(
      batch,
      recordId: person.id,
      recordType: 'person',
      action: before.exists ? auditAction : 'create',
      before: before.data(),
      after: _mapper.personToMap(person),
    );
    await batch.commit();
  }

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) async {
    final ref = _deals.doc(deal.id);
    final before = await ref.get();
    final after = _mapper.dealToMap(deal);
    final batch = _firestore.batch();
    batch.set(ref, after, SetOptions(merge: true));
    _appendAuditToBatch(
      batch,
      recordId: deal.id,
      recordType: 'deal',
      action: before.exists ? auditAction : 'create',
      before: before.data(),
      after: after,
    );
    await batch.commit();
  }

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) async {
    final ref = _settlements.doc(settlement.id);
    final before = await ref.get();
    final after = _mapper.settlementToMap(settlement);
    final batch = _firestore.batch();
    batch.set(ref, after, SetOptions(merge: true));
    _appendAuditToBatch(
      batch,
      recordId: settlement.id,
      recordType: 'settlement',
      action: before.exists ? auditAction : 'create',
      before: before.data(),
      after: after,
    );
    await batch.commit();
  }

  @override
  Future<void> archivePerson(ZarPerson person) async {
    final updated = ZarPerson(
      id: person.id,
      displayName: person.displayName,
      phone: person.phone,
      note: person.note,
      archived: true,
      createdAt: person.createdAt,
      updatedAt: DateTime.now().toUtc(),
      createdBy: person.createdBy,
    );
    await savePerson(updated, auditAction: 'archive');
  }

  @override
  Future<void> restorePerson(ZarPerson person) async {
    final updated = ZarPerson(
      id: person.id,
      displayName: person.displayName,
      phone: person.phone,
      note: person.note,
      archived: false,
      createdAt: person.createdAt,
      updatedAt: DateTime.now().toUtc(),
      createdBy: person.createdBy,
    );
    await savePerson(updated, auditAction: 'restore');
  }

  void _appendAuditToBatch(
    WriteBatch batch, {
    required String recordId,
    required String recordType,
    required String action,
    required Map<String, Object?>? before,
    required Map<String, Object?> after,
  }) {
    final ref = _audit.doc();
    batch.set(ref, {
      'recordId': recordId,
      'recordType': recordType,
      'action': action,
      'actorUid': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'before': before,
      'after': after,
    });
  }
}
