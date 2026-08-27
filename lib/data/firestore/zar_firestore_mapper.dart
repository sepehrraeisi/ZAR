import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/zar_domain_models.dart';

class ZarFirestoreMapper {
  const ZarFirestoreMapper();

  Map<String, Object?> personToMap(ZarPerson person) => {
        'displayName': person.displayName,
        'normalizedName': normalizePersonName(person.displayName),
        'phone': person.phone,
        'note': person.note,
        'archived': person.archived,
        'createdAt': Timestamp.fromDate(person.createdAt.toUtc()),
        'updatedAt': Timestamp.fromDate(person.updatedAt.toUtc()),
        'createdBy': person.createdBy,
      };

  ZarPerson personFromMap(String id, Map<String, Object?> map) => ZarPerson(
        id: id,
        displayName: map['displayName']! as String,
        phone: map['phone'] as String?,
        note: map['note'] as String?,
        archived: map['archived'] as bool? ?? false,
        createdAt: _date(map['createdAt']),
        updatedAt: _date(map['updatedAt']),
        createdBy: map['createdBy']! as String,
      );

  Map<String, Object?> dealToMap(ZarDeal deal) => {
        'dealType': deal.type.name,
        'assetType': deal.amount.assetType.name,
        'personId': deal.personId,
        'dealAt': Timestamp.fromDate(deal.dealAt.toUtc()),
        'status': deal.status.name,
        ..._amountFields(deal.amount),
        'note': deal.note,
        'createdBy': deal.createdBy,
        'createdAt': Timestamp.fromDate(deal.createdAt.toUtc()),
        'updatedAt': Timestamp.fromDate(deal.updatedAt.toUtc()),
      };

  ZarDeal dealFromMap({
    required String id,
    required String businessId,
    required Map<String, Object?> map,
  }) =>
      ZarDeal(
        id: id,
        businessId: businessId,
        type: ZarDealType.values.byName(map['dealType']! as String),
        personId: map['personId']! as String,
        amount: _amountFromFirestore(map),
        dealAt: _date(map['dealAt']),
        status: ZarDealStatus.values.byName(map['status']! as String),
        note: map['note'] as String?,
        createdBy: map['createdBy']! as String,
        createdAt: _date(map['createdAt']),
        updatedAt: _date(map['updatedAt']),
      );

  Map<String, Object?> settlementToMap(ZarSettlement settlement) => {
        'dealId': settlement.dealId,
        'personId': settlement.personId,
        'direction': settlement.direction.name,
        'assetType': settlement.amount.assetType.name,
        'status': settlement.status.name,
        'scheduledAt': Timestamp.fromDate(settlement.scheduledAt.toUtc()),
        'hasTime': settlement.hasTime,
        'completedAt': settlement.completedAt == null
            ? null
            : Timestamp.fromDate(settlement.completedAt!.toUtc()),
        'completedBy': settlement.completedBy,
        ..._amountFields(settlement.amount),
        'note': settlement.note,
        'createdBy': settlement.createdBy,
        'createdAt': Timestamp.fromDate(settlement.createdAt.toUtc()),
        'updatedAt': Timestamp.fromDate(settlement.updatedAt.toUtc()),
      };

  ZarSettlement settlementFromMap({
    required String id,
    required String businessId,
    required Map<String, Object?> map,
  }) =>
      ZarSettlement(
        id: id,
        businessId: businessId,
        dealId: map['dealId'] as String?,
        personId: map['personId']! as String,
        direction: ZarSettlementDirection.values.byName(map['direction']! as String),
        amount: _amountFromFirestore(map),
        scheduledAt: _date(map['scheduledAt']),
        hasTime: map['hasTime'] as bool? ?? true,
        status: ZarSettlementStatus.values.byName(map['status']! as String),
        completedAt: map['completedAt'] == null ? null : _date(map['completedAt']),
        completedBy: map['completedBy'] as String?,
        note: map['note'] as String?,
        createdBy: map['createdBy']! as String,
        createdAt: _date(map['createdAt']),
        updatedAt: _date(map['updatedAt']),
      );

  Map<String, Object?> _amountFields(ZarAssetAmount amount) {
    switch (amount) {
      case ZarGoldAssetAmount(:final value):
        return {
          'goldWeightDecimal': value.decimal,
          'goldUnit': value.unit.name,
          'goldPurity': value.purity,
        };
      case ZarCurrencyAssetAmount(:final value):
        return {
          'currencyCode': value.code,
          'currencyMinorUnits': value.minorUnits,
          'currencyMinorUnitScale': value.minorUnitScale,
        };
    }
  }

  ZarAssetAmount _amountFromFirestore(Map<String, Object?> map) {
    final type = ZarAssetType.values.byName(map['assetType']! as String);
    switch (type) {
      case ZarAssetType.gold:
        return ZarGoldAssetAmount(
          ZarGoldQuantity(
            decimal: map['goldWeightDecimal']! as String,
            unit: ZarGoldUnit.values.byName(map['goldUnit']! as String),
            purity: map['goldPurity'] as String?,
          ),
        );
      case ZarAssetType.currency:
        return ZarCurrencyAssetAmount(
          ZarCurrencyAmount(
            code: map['currencyCode']! as String,
            minorUnits: map['currencyMinorUnits']! as int,
            minorUnitScale: map['currencyMinorUnitScale'] as int? ?? 2,
          ),
        );
    }
  }

  DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    throw const FormatException('Expected Firestore Timestamp.');
  }
}

String normalizePersonName(String input) => input
    .trim()
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();
