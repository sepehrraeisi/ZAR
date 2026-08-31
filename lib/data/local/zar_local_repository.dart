import 'package:drift/drift.dart';

import '../../domain/zar_domain_models.dart';
import '../../domain/zar_reminder_plan.dart';
import '../zar_domain_repository.dart';
import 'zar_local_database.dart';

class ZarLocalRepository implements ZarDomainRepository {
  ZarLocalRepository(this.database);

  final ZarLocalDatabase database;

  Future<void> ensureReady() => database.ensureReady();

  Future<void> close() => database.close();

  @override
  Future<ZarDomainSnapshot> loadCompleteSnapshot() async {
    final people = await database.select(database.zarPeople).get();
    final deals = await database.select(database.zarDeals).get();
    final settlements = await database.select(database.zarSettlements).get();
    final allRulesQuery = database.select(database.zarReminderRules)
      ..orderBy([
        (row) => OrderingTerm.asc(row.settlementId),
        (row) => OrderingTerm.asc(row.position),
      ]);
    final rules = await allRulesQuery.get();
    final rulesBySettlement = _groupRules(rules);
    return ZarDomainSnapshot(
      people: people.map(_personFromRow).toList(growable: false),
      deals: deals.map(_dealFromRow).toList(growable: false),
      settlements: settlements
          .map((row) => _settlementFromRow(row, rulesBySettlement[row.id]))
          .toList(growable: false),
    );
  }

  @override
  Future<void> replaceCompleteSnapshot(ZarDomainSnapshot snapshot) async {
    _validateSnapshot(snapshot);
    await database.transaction(() async {
      await database.delete(database.zarReminderRules).go();
      await database.delete(database.zarSettlements).go();
      await database.delete(database.zarDeals).go();
      await database.delete(database.zarPeople).go();
      for (final person in snapshot.people) {
        await database.into(database.zarPeople).insert(_personToRow(person));
      }
      for (final deal in snapshot.deals) {
        await database.into(database.zarDeals).insert(_dealToRow(deal));
      }
      for (final settlement in snapshot.settlements) {
        await _insertSettlement(settlement);
      }
    });
  }

  @override
  Future<List<ZarPerson>> loadActivePeople({int limit = 100}) async {
    final query = database.select(database.zarPeople)
      ..where((row) => row.archived.equals(false))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMicros)])
      ..limit(limit);
    return (await query.get()).map(_personFromRow).toList(growable: false);
  }

  @override
  Future<List<ZarPerson>> loadArchivedPeople({int limit = 100}) async {
    final query = database.select(database.zarPeople)
      ..where((row) => row.archived.equals(true))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMicros)])
      ..limit(limit);
    return (await query.get()).map(_personFromRow).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadOpenSettlements({
    required DateTime from,
    required DateTime through,
    int limit = 250,
  }) => _loadSettlements(
    where: (row) =>
        row.status.equals(ZarSettlementStatus.open.name) &
        row.scheduledAtMicros.isBiggerOrEqualValue(_micros(from)) &
        row.scheduledAtMicros.isSmallerThanValue(_micros(through)),
    ascending: true,
    limit: limit,
  );

  @override
  Future<List<ZarSettlement>> loadOverdueSettlements({
    required DateTime now,
    int limit = 100,
  }) => _loadSettlements(
    where: (row) =>
        row.status.equals(ZarSettlementStatus.open.name) &
        row.scheduledAtMicros.isSmallerThanValue(_micros(now)),
    ascending: true,
    limit: limit,
  );

  @override
  Future<List<ZarSettlement>> loadRecentSettlements({int limit = 250}) =>
      _loadSettlements(limit: limit);

  @override
  Future<List<ZarDeal>> loadRecentDeals({int limit = 250}) async {
    final query = database.select(database.zarDeals)
      ..orderBy([(row) => OrderingTerm.desc(row.dealAtMicros)])
      ..limit(limit);
    return (await query.get()).map(_dealFromRow).toList(growable: false);
  }

  @override
  Future<List<ZarSettlement>> loadPersonSettlements({
    required String personId,
    int limit = 100,
  }) => _loadSettlements(
    where: (row) => row.personId.equals(personId),
    limit: limit,
  );

  @override
  Future<List<ZarDeal>> loadPersonDeals({
    required String personId,
    int limit = 100,
  }) async {
    final query = database.select(database.zarDeals)
      ..where((row) => row.personId.equals(personId))
      ..orderBy([(row) => OrderingTerm.desc(row.dealAtMicros)])
      ..limit(limit);
    return (await query.get()).map(_dealFromRow).toList(growable: false);
  }

  @override
  Future<void> savePerson(ZarPerson person, {String auditAction = 'edit'}) =>
      database
          .into(database.zarPeople)
          .insertOnConflictUpdate(_personToRow(person));

  @override
  Future<void> saveDeal(ZarDeal deal, {String auditAction = 'edit'}) =>
      database.into(database.zarDeals).insertOnConflictUpdate(_dealToRow(deal));

  @override
  Future<void> saveSettlement(
    ZarSettlement settlement, {
    String auditAction = 'edit',
  }) => database.transaction(() async {
    await database
        .into(database.zarSettlements)
        .insertOnConflictUpdate(_settlementToRow(settlement));
    await (database.delete(
      database.zarReminderRules,
    )..where((row) => row.settlementId.equals(settlement.id))).go();
    await _insertReminderRules(settlement);
  });

  @override
  Future<void> archivePerson(ZarPerson person) =>
      savePerson(_copyPerson(person, archived: true), auditAction: 'archive');

  @override
  Future<void> restorePerson(ZarPerson person) =>
      savePerson(_copyPerson(person, archived: false), auditAction: 'restore');

  Future<List<ZarSettlement>> _loadSettlements({
    Expression<bool> Function(ZarSettlements row)? where,
    bool ascending = false,
    required int limit,
  }) async {
    final query = database.select(database.zarSettlements);
    if (where != null) query.where(where);
    query
      ..orderBy([
        (row) => ascending
            ? OrderingTerm.asc(row.scheduledAtMicros)
            : OrderingTerm.desc(row.scheduledAtMicros),
      ])
      ..limit(limit);
    final rows = await query.get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList(growable: false);
    final ruleQuery = database.select(database.zarReminderRules)
      ..where((row) => row.settlementId.isIn(ids))
      ..orderBy([
        (row) => OrderingTerm.asc(row.settlementId),
        (row) => OrderingTerm.asc(row.position),
      ]);
    final rules = _groupRules(await ruleQuery.get());
    return rows
        .map((row) => _settlementFromRow(row, rules[row.id]))
        .toList(growable: false);
  }

  Future<void> _insertSettlement(ZarSettlement settlement) async {
    await database
        .into(database.zarSettlements)
        .insert(_settlementToRow(settlement));
    await _insertReminderRules(settlement);
  }

  Future<void> _insertReminderRules(ZarSettlement settlement) async {
    for (final (position, rule) in settlement.reminderPlan.rules.indexed) {
      await database
          .into(database.zarReminderRules)
          .insert(
            ZarReminderRulesCompanion.insert(
              settlementId: settlement.id,
              ruleId: rule.id,
              position: position,
              type: rule.type.name,
              minutesBefore: Value(rule.minutesBefore),
              customAtMicros: Value(
                rule.customAt == null ? null : _micros(rule.customAt!),
              ),
              enabled: rule.enabled,
            ),
          );
    }
  }

  Map<String, List<LocalReminderRuleRow>> _groupRules(
    List<LocalReminderRuleRow> rows,
  ) {
    final grouped = <String, List<LocalReminderRuleRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.settlementId, () => []).add(row);
    }
    return grouped;
  }

  ZarPerson _personFromRow(LocalPersonRow row) => ZarPerson(
    id: row.id,
    displayName: row.displayName,
    phone: row.phone,
    note: row.note,
    archived: row.archived,
    createdAt: _date(row.createdAtMicros),
    updatedAt: _date(row.updatedAtMicros),
    createdBy: row.createdBy,
  );

  ZarDeal _dealFromRow(LocalDealRow row) => ZarDeal(
    id: row.id,
    businessId: row.businessId,
    type: ZarDealType.values.byName(row.type),
    personId: row.personId,
    amount: _amountFromColumns(
      assetType: row.assetType,
      goldDecimal: row.goldDecimal,
      goldUnit: row.goldUnit,
      goldPurity: row.goldPurity,
      currencyCode: row.currencyCode,
      currencyMinorUnits: row.currencyMinorUnits,
      currencyMinorUnitScale: row.currencyMinorUnitScale,
    ),
    pricing: _dealPricingFromColumns(
      kind: row.pricingKind,
      goldFineness: row.goldFineness,
      goldFinenessDecimal: row.goldFinenessDecimal,
      goldPriceReferenceFineness: row.goldPriceReferenceFineness,
      goldInputDecimal: row.goldInputDecimal,
      goldInputUnit: row.goldInputUnit,
      goldPriceUnit: row.goldPriceUnit,
      tomanRateDecimal: row.tomanRateDecimal,
      totalToman: row.totalToman,
    ),
    dealAt: _date(row.dealAtMicros),
    status: ZarDealStatus.values.byName(row.status),
    note: row.note,
    createdBy: row.createdBy,
    createdAt: _date(row.createdAtMicros),
    updatedAt: _date(row.updatedAtMicros),
  );

  ZarSettlement _settlementFromRow(
    LocalSettlementRow row,
    List<LocalReminderRuleRow>? rules,
  ) {
    final reminderRules = (rules ?? const <LocalReminderRuleRow>[])
        .map(_reminderRuleFromRow)
        .toList(growable: false);
    return ZarSettlement(
      id: row.id,
      businessId: row.businessId,
      dealId: row.dealId,
      personId: row.personId,
      direction: ZarSettlementDirection.values.byName(row.direction),
      amount: _amountFromColumns(
        assetType: row.assetType,
        goldDecimal: row.goldDecimal,
        goldUnit: row.goldUnit,
        goldPurity: row.goldPurity,
        currencyCode: row.currencyCode,
        currencyMinorUnits: row.currencyMinorUnits,
        currencyMinorUnitScale: row.currencyMinorUnitScale,
      ),
      scheduledAt: _date(row.scheduledAtMicros),
      hasTime: row.hasTime,
      status: ZarSettlementStatus.values.byName(row.status),
      reminderPlan: ZarReminderPlan(
        rules: reminderRules,
        snoozedUntil: row.snoozedUntilMicros == null
            ? null
            : _date(row.snoozedUntilMicros!),
      ),
      completedAt: row.completedAtMicros == null
          ? null
          : _date(row.completedAtMicros!),
      completedBy: row.completedBy,
      note: row.note,
      createdBy: row.createdBy,
      createdAt: _date(row.createdAtMicros),
      updatedAt: _date(row.updatedAtMicros),
    );
  }

  ZarPeopleCompanion _personToRow(ZarPerson person) =>
      ZarPeopleCompanion.insert(
        id: person.id,
        displayName: person.displayName,
        phone: Value(person.phone),
        note: Value(person.note),
        archived: Value(person.archived),
        createdAtMicros: _micros(person.createdAt),
        updatedAtMicros: _micros(person.updatedAt),
        createdBy: person.createdBy,
      );

  ZarDealsCompanion _dealToRow(ZarDeal deal) {
    final pricing = deal.pricing;
    final persistedAmount = pricing is ZarGoldDealPricing
        ? ZarGoldAssetAmount(
            ZarGoldQuantity(
              decimal: pricing.normalizedWeightGrams,
              unit: ZarGoldUnit.gram,
              purity: pricing.fineness.toString(),
            ),
          )
        : deal.amount;
    final amount = _amountColumns(persistedAmount);
    return ZarDealsCompanion.insert(
      id: deal.id,
      businessId: deal.businessId,
      type: deal.type.name,
      personId: deal.personId,
      assetType: deal.amount.assetType.name,
      goldDecimal: Value(amount.goldDecimal),
      goldUnit: Value(amount.goldUnit),
      goldPurity: Value(amount.goldPurity),
      currencyCode: Value(amount.currencyCode),
      currencyMinorUnits: Value(amount.currencyMinorUnits),
      currencyMinorUnitScale: Value(amount.currencyMinorUnitScale),
      pricingKind: Value(
        pricing == null
            ? null
            : pricing is ZarGoldDealPricing
            ? 'gold'
            : 'currency',
      ),
      goldFineness: Value(
        pricing is ZarGoldDealPricing && !pricing.fineness.contains('.')
            ? int.parse(pricing.fineness)
            : null,
      ),
      goldFinenessDecimal: Value(
        pricing is ZarGoldDealPricing ? pricing.fineness : null,
      ),
      goldPriceReferenceFineness: Value(
        pricing is ZarGoldDealPricing ? pricing.priceReferenceFineness : null,
      ),
      goldInputDecimal: Value(
        pricing is ZarGoldDealPricing ? pricing.inputWeight : null,
      ),
      goldInputUnit: Value(
        pricing is ZarGoldDealPricing ? pricing.inputWeightUnit.name : null,
      ),
      goldPriceUnit: Value(
        pricing is ZarGoldDealPricing ? pricing.priceUnit.name : null,
      ),
      tomanRateDecimal: Value(switch (pricing) {
        ZarGoldDealPricing() =>
          pricing.pricePerUnitToman.wholeTomans.toString(),
        ZarCurrencyDealPricing() => pricing.tomanPerUnit,
        null => null,
      }),
      totalToman: Value(pricing?.totalToman.wholeTomans),
      dealAtMicros: _micros(deal.dealAt),
      status: deal.status.name,
      note: Value(deal.note),
      createdBy: deal.createdBy,
      createdAtMicros: _micros(deal.createdAt),
      updatedAtMicros: _micros(deal.updatedAt),
    );
  }

  ZarDealPricing? _dealPricingFromColumns({
    required String? kind,
    required int? goldFineness,
    required String? goldFinenessDecimal,
    required String? goldPriceReferenceFineness,
    required String? goldInputDecimal,
    required String? goldInputUnit,
    required String? goldPriceUnit,
    required String? tomanRateDecimal,
    required int? totalToman,
  }) {
    if (kind == null) return null;
    if (tomanRateDecimal == null || totalToman == null) {
      throw const FormatException('Stored deal pricing is incomplete.');
    }
    if (kind == 'gold') {
      final fineness = goldFinenessDecimal ?? goldFineness?.toString();
      if (fineness == null) {
        throw const FormatException('Stored gold fineness is missing.');
      }
      return ZarGoldDealPricing(
        fineness: fineness,
        priceReferenceFineness: goldPriceReferenceFineness ?? fineness,
        inputWeight: goldInputDecimal ?? '1',
        inputWeightUnit: ZarGoldUnit.values.byName(
          goldInputUnit ?? ZarGoldUnit.gram.name,
        ),
        priceUnit: ZarGoldUnit.values.byName(
          goldPriceUnit ?? ZarGoldUnit.gram.name,
        ),
        pricePerUnitToman: ZarTomanAmount(int.parse(tomanRateDecimal)),
        totalToman: ZarTomanAmount(totalToman),
      );
    }
    if (kind == 'currency') {
      return ZarCurrencyDealPricing(
        tomanPerUnit: tomanRateDecimal,
        totalToman: ZarTomanAmount(totalToman),
      );
    }
    throw FormatException('Unsupported stored deal pricing kind: $kind');
  }

  ZarSettlementsCompanion _settlementToRow(ZarSettlement settlement) {
    final amount = _amountColumns(settlement.amount);
    return ZarSettlementsCompanion.insert(
      id: settlement.id,
      businessId: settlement.businessId,
      dealId: Value(settlement.dealId),
      personId: settlement.personId,
      direction: settlement.direction.name,
      assetType: settlement.amount.assetType.name,
      goldDecimal: Value(amount.goldDecimal),
      goldUnit: Value(amount.goldUnit),
      goldPurity: Value(amount.goldPurity),
      currencyCode: Value(amount.currencyCode),
      currencyMinorUnits: Value(amount.currencyMinorUnits),
      currencyMinorUnitScale: Value(amount.currencyMinorUnitScale),
      scheduledAtMicros: _micros(settlement.scheduledAt),
      hasTime: settlement.hasTime,
      status: settlement.status.name,
      snoozedUntilMicros: Value(
        settlement.reminderPlan.snoozedUntil == null
            ? null
            : _micros(settlement.reminderPlan.snoozedUntil!),
      ),
      completedAtMicros: Value(
        settlement.completedAt == null
            ? null
            : _micros(settlement.completedAt!),
      ),
      completedBy: Value(settlement.completedBy),
      note: Value(settlement.note),
      createdBy: settlement.createdBy,
      createdAtMicros: _micros(settlement.createdAt),
      updatedAtMicros: _micros(settlement.updatedAt),
    );
  }

  ZarReminderRule _reminderRuleFromRow(LocalReminderRuleRow row) {
    final type = ZarReminderRuleType.values.byName(row.type);
    if (type == ZarReminderRuleType.offset) {
      final minutes = row.minutesBefore;
      if (minutes == null || minutes <= 0) {
        throw const FormatException('Invalid persisted reminder offset.');
      }
      return ZarReminderRule.offset(
        id: row.ruleId,
        minutesBefore: minutes,
        enabled: row.enabled,
      );
    }
    if (row.customAtMicros == null) {
      throw const FormatException('Invalid persisted custom reminder.');
    }
    return ZarReminderRule.custom(
      id: row.ruleId,
      customAt: _date(row.customAtMicros!),
      enabled: row.enabled,
    );
  }

  ZarAssetAmount _amountFromColumns({
    required String assetType,
    required String? goldDecimal,
    required String? goldUnit,
    required String? goldPurity,
    required String? currencyCode,
    required int? currencyMinorUnits,
    required int? currencyMinorUnitScale,
  }) {
    final type = ZarAssetType.values.byName(assetType);
    if (type == ZarAssetType.gold) {
      if (goldDecimal == null || goldUnit == null) {
        throw const FormatException('Invalid persisted gold amount.');
      }
      return ZarGoldAssetAmount(
        ZarGoldQuantity(
          decimal: goldDecimal,
          unit: ZarGoldUnit.values.byName(goldUnit),
          purity: goldPurity,
        ),
      );
    }
    if (currencyCode == null ||
        currencyMinorUnits == null ||
        currencyMinorUnitScale == null) {
      throw const FormatException('Invalid persisted currency amount.');
    }
    return ZarCurrencyAssetAmount(
      ZarCurrencyAmount(
        code: currencyCode,
        minorUnits: currencyMinorUnits,
        minorUnitScale: currencyMinorUnitScale,
      ),
    );
  }

  _AmountColumns _amountColumns(ZarAssetAmount amount) {
    return switch (amount) {
      ZarGoldAssetAmount(:final value) => _AmountColumns(
        goldDecimal: value.decimal,
        goldUnit: value.unit.name,
        goldPurity: value.purity,
      ),
      ZarCurrencyAssetAmount(:final value) => _AmountColumns(
        currencyCode: value.code,
        currencyMinorUnits: value.minorUnits,
        currencyMinorUnitScale: value.minorUnitScale,
      ),
    };
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

  void _validateSnapshot(ZarDomainSnapshot snapshot) {
    final people = snapshot.people.map((item) => item.id).toSet();
    final deals = snapshot.deals.map((item) => item.id).toSet();
    final settlements = snapshot.settlements.map((item) => item.id).toSet();
    if (people.length != snapshot.people.length ||
        deals.length != snapshot.deals.length ||
        settlements.length != snapshot.settlements.length) {
      throw const FormatException('Snapshot contains duplicate identifiers.');
    }
    for (final deal in snapshot.deals) {
      if (!people.contains(deal.personId)) {
        throw FormatException('Deal ${deal.id} references an unknown person.');
      }
    }
    for (final settlement in snapshot.settlements) {
      if (!people.contains(settlement.personId)) {
        throw FormatException(
          'Settlement ${settlement.id} references an unknown person.',
        );
      }
      if (settlement.dealId != null && !deals.contains(settlement.dealId)) {
        throw FormatException(
          'Settlement ${settlement.id} references an unknown deal.',
        );
      }
    }
  }

  int _micros(DateTime value) => value.toUtc().microsecondsSinceEpoch;
  DateTime _date(int micros) =>
      DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
}

class _AmountColumns {
  const _AmountColumns({
    this.goldDecimal,
    this.goldUnit,
    this.goldPurity,
    this.currencyCode,
    this.currencyMinorUnits,
    this.currencyMinorUnitScale,
  });

  final String? goldDecimal;
  final String? goldUnit;
  final String? goldPurity;
  final String? currencyCode;
  final int? currencyMinorUnits;
  final int? currencyMinorUnitScale;
}
