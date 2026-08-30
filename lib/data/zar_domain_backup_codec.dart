import 'dart:convert';

import '../domain/zar_domain_models.dart';
import '../domain/zar_reminder_plan.dart';

/// Lossless backup format for production business data.
///
/// Unlike the legacy presentation export, this format stores exact domain
/// values (gold decimal strings, currency minor units, canonical timestamps)
/// and can therefore be used as the basis of a future restore workflow.
class ZarDomainBackupBundle {
  const ZarDomainBackupBundle({
    required this.businessId,
    required this.generatedAt,
    required this.people,
    required this.deals,
    required this.settlements,
    this.exportVersion = 4,
  });

  final int exportVersion;
  final String businessId;
  final DateTime generatedAt;
  final List<ZarPerson> people;
  final List<ZarDeal> deals;
  final List<ZarSettlement> settlements;
}

class ZarDomainBackupCodec {
  const ZarDomainBackupCodec();

  static const supportedVersion = 4;
  static const supportedImportVersions = {2, 3, 4};

  String encodeJson(ZarDomainBackupBundle bundle) {
    if (bundle.exportVersion != supportedVersion) {
      throw FormatException(
        'Unsupported ZAR+ domain export version: ${bundle.exportVersion}',
      );
    }
    if (bundle.businessId.trim().isEmpty) {
      throw const FormatException('Backup businessId is required.');
    }

    final payload = <String, Object?>{
      'app': 'ZAR+',
      'format': 'domain-backup',
      'exportVersion': bundle.exportVersion,
      'businessId': bundle.businessId,
      'generatedAt': bundle.generatedAt.toUtc().toIso8601String(),
      'people': bundle.people.map(_personToMap).toList(growable: false),
      'deals': bundle.deals.map(_dealToMap).toList(growable: false),
      'settlements': bundle.settlements.map(_settlementToMap).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ZarDomainBackupBundle decodeJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Invalid ZAR+ backup document.');
    }
    final raw = Map<String, Object?>.from(decoded);
    if (raw['app'] != 'ZAR+' || raw['format'] != 'domain-backup') {
      throw const FormatException('This file is not a ZAR+ domain backup.');
    }
    final version = raw['exportVersion'];
    if (version is! int || !supportedImportVersions.contains(version)) {
      throw FormatException('Unsupported ZAR+ domain export version: $version');
    }
    final businessId = (raw['businessId'] as String?)?.trim() ?? '';
    if (businessId.isEmpty) {
      throw const FormatException('Backup businessId is missing.');
    }

    final people = _mapList(raw['people'], _personFromMap);
    final deals = _mapList(raw['deals'], (map) => _dealFromMap(map, businessId));
    final settlements = _mapList(
      raw['settlements'],
      (map) => _settlementFromMap(map, businessId),
    );

    _validateReferences(people: people, deals: deals, settlements: settlements);

    return ZarDomainBackupBundle(
      exportVersion: version,
      businessId: businessId,
      generatedAt: _date(raw['generatedAt'], 'generatedAt'),
      people: people,
      deals: deals,
      settlements: settlements,
    );
  }

  List<T> _mapList<T>(Object? raw, T Function(Map<String, Object?>) mapper) {
    if (raw == null) return const [];
    if (raw is! List) throw const FormatException('Invalid backup collection.');
    return raw
        .map((item) {
          if (item is! Map) throw const FormatException('Invalid backup record.');
          return mapper(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }

  Map<String, Object?> _personToMap(ZarPerson person) => {
        'id': person.id,
        'displayName': person.displayName,
        'phone': person.phone,
        'note': person.note,
        'archived': person.archived,
        'createdAt': person.createdAt.toUtc().toIso8601String(),
        'updatedAt': person.updatedAt.toUtc().toIso8601String(),
        'createdBy': person.createdBy,
      };

  ZarPerson _personFromMap(Map<String, Object?> map) => ZarPerson(
        id: _requiredString(map['id'], 'person.id'),
        displayName: _requiredString(map['displayName'], 'person.displayName'),
        phone: map['phone'] as String?,
        note: map['note'] as String?,
        archived: map['archived'] as bool? ?? false,
        createdAt: _date(map['createdAt'], 'person.createdAt'),
        updatedAt: _date(map['updatedAt'], 'person.updatedAt'),
        createdBy: _requiredString(map['createdBy'], 'person.createdBy'),
      );

  Map<String, Object?> _dealToMap(ZarDeal deal) => {
        'id': deal.id,
        'type': deal.type.name,
        'personId': deal.personId,
        'amount': deal.amount.toMap(),
        'pricing': deal.pricing?.toMap(),
        'dealAt': deal.dealAt.toUtc().toIso8601String(),
        'status': deal.status.name,
        'note': deal.note,
        'createdBy': deal.createdBy,
        'createdAt': deal.createdAt.toUtc().toIso8601String(),
        'updatedAt': deal.updatedAt.toUtc().toIso8601String(),
      };

  ZarDeal _dealFromMap(Map<String, Object?> map, String businessId) {
    var amount = ZarAssetAmount.fromMap(_requiredMap(map['amount'], 'deal.amount'));
    ZarDealPricing? pricing;
    if (map['pricing'] != null) {
      final pricingMap = _requiredMap(map['pricing'], 'deal.pricing');
      if (pricingMap['kind'] == 'gold' &&
          pricingMap['pricePerUnitToman'] == null) {
        if (amount is! ZarGoldAssetAmount) {
          throw const FormatException('Gold pricing requires a gold amount.');
        }
        pricing = ZarGoldDealPricing(
          fineness: pricingMap['fineness']! as int,
          inputWeight: amount.value.decimal,
          inputWeightUnit: amount.value.unit,
          priceUnit: ZarGoldUnit.gram,
          pricePerUnitToman: ZarTomanAmount.fromMap(
            Map<String, Object?>.from(pricingMap['pricePerGramToman']! as Map),
          ),
          totalToman: ZarTomanAmount.fromMap(
            Map<String, Object?>.from(pricingMap['totalToman']! as Map),
          ),
        );
      } else {
        pricing = ZarDealPricing.fromMap(pricingMap);
      }
    }
    if (pricing is ZarGoldDealPricing) {
      amount = ZarGoldAssetAmount(
        ZarGoldQuantity(
          decimal: pricing.normalizedWeightGrams,
          unit: ZarGoldUnit.gram,
          purity: pricing.fineness.toString(),
        ),
      );
    }
    return ZarDeal(
        id: _requiredString(map['id'], 'deal.id'),
        businessId: businessId,
        type: ZarDealType.values.byName(_requiredString(map['type'], 'deal.type')),
        personId: _requiredString(map['personId'], 'deal.personId'),
        amount: amount,
        pricing: pricing,
        dealAt: _date(map['dealAt'], 'deal.dealAt'),
        status: ZarDealStatus.values.byName(
          _requiredString(map['status'], 'deal.status'),
        ),
        note: map['note'] as String?,
        createdBy: _requiredString(map['createdBy'], 'deal.createdBy'),
        createdAt: _date(map['createdAt'], 'deal.createdAt'),
        updatedAt: _date(map['updatedAt'], 'deal.updatedAt'),
      );
  }

  Map<String, Object?> _settlementToMap(ZarSettlement settlement) => {
        'id': settlement.id,
        'dealId': settlement.dealId,
        'personId': settlement.personId,
        'direction': settlement.direction.name,
        'amount': settlement.amount.toMap(),
        'scheduledAt': settlement.scheduledAt.toUtc().toIso8601String(),
        'hasTime': settlement.hasTime,
        'status': settlement.status.name,
        'reminderPlan': settlement.reminderPlan.toMap(),
        'completedAt': settlement.completedAt?.toUtc().toIso8601String(),
        'completedBy': settlement.completedBy,
        'note': settlement.note,
        'createdBy': settlement.createdBy,
        'createdAt': settlement.createdAt.toUtc().toIso8601String(),
        'updatedAt': settlement.updatedAt.toUtc().toIso8601String(),
      };

  ZarSettlement _settlementFromMap(
    Map<String, Object?> map,
    String businessId,
  ) =>
      ZarSettlement(
        id: _requiredString(map['id'], 'settlement.id'),
        businessId: businessId,
        dealId: map['dealId'] as String?,
        personId: _requiredString(map['personId'], 'settlement.personId'),
        direction: ZarSettlementDirection.values.byName(
          _requiredString(map['direction'], 'settlement.direction'),
        ),
        amount: ZarAssetAmount.fromMap(
          _requiredMap(map['amount'], 'settlement.amount'),
        ),
        scheduledAt: _date(map['scheduledAt'], 'settlement.scheduledAt'),
        hasTime: map['hasTime'] as bool? ?? false,
        status: ZarSettlementStatus.values.byName(
          _requiredString(map['status'], 'settlement.status'),
        ),
        reminderPlan: map['reminderPlan'] == null
            ? const ZarReminderPlan()
            : ZarReminderPlan.fromMap(
                _requiredMap(map['reminderPlan'], 'settlement.reminderPlan'),
              ),
        completedAt: map['completedAt'] == null
            ? null
            : _date(map['completedAt'], 'settlement.completedAt'),
        completedBy: map['completedBy'] as String?,
        note: map['note'] as String?,
        createdBy: _requiredString(map['createdBy'], 'settlement.createdBy'),
        createdAt: _date(map['createdAt'], 'settlement.createdAt'),
        updatedAt: _date(map['updatedAt'], 'settlement.updatedAt'),
      );

  void _validateReferences({
    required List<ZarPerson> people,
    required List<ZarDeal> deals,
    required List<ZarSettlement> settlements,
  }) {
    final peopleIds = people.map((p) => p.id).toSet();
    final dealIds = deals.map((d) => d.id).toSet();

    if (peopleIds.length != people.length || dealIds.length != deals.length) {
      throw const FormatException('Backup contains duplicate identifiers.');
    }
    final settlementIds = settlements.map((s) => s.id).toSet();
    if (settlementIds.length != settlements.length) {
      throw const FormatException('Backup contains duplicate identifiers.');
    }

    for (final deal in deals) {
      if (!peopleIds.contains(deal.personId)) {
        throw FormatException('Deal ${deal.id} references an unknown person.');
      }
    }
    for (final settlement in settlements) {
      if (!peopleIds.contains(settlement.personId)) {
        throw FormatException(
          'Settlement ${settlement.id} references an unknown person.',
        );
      }
      if (settlement.dealId != null && !dealIds.contains(settlement.dealId)) {
        throw FormatException(
          'Settlement ${settlement.id} references an unknown deal.',
        );
      }
    }
  }

  String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field is required.');
    }
    return value;
  }

  Map<String, Object?> _requiredMap(Object? value, String field) {
    if (value is! Map) throw FormatException('$field is invalid.');
    return Map<String, Object?>.from(value);
  }

  DateTime _date(Object? value, String field) {
    if (value is! String) throw FormatException('$field is invalid.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('$field is invalid.');
    return parsed.toUtc();
  }
}
