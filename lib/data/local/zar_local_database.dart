import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/zar_domain_models.dart';

part 'zar_local_database.g.dart';

@DataClassName('LocalPersonRow')
class ZarPeople extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMicros => integer()();
  IntColumn get updatedAtMicros => integer()();
  TextColumn get createdBy => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalDealRow')
class ZarDeals extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get type => text()();
  TextColumn get personId => text().references(ZarPeople, #id)();
  TextColumn get assetType => text()();
  TextColumn get goldDecimal => text().nullable()();
  TextColumn get goldUnit => text().nullable()();
  TextColumn get goldPurity => text().nullable()();
  TextColumn get currencyCode => text().nullable()();
  IntColumn get currencyMinorUnits => integer().nullable()();
  IntColumn get currencyMinorUnitScale => integer().nullable()();
  TextColumn get pricingKind => text().nullable()();
  IntColumn get goldFineness => integer().nullable()();
  TextColumn get goldFinenessDecimal => text().nullable()();
  TextColumn get goldPriceReferenceFineness => text().nullable()();
  TextColumn get goldInputDecimal => text().nullable()();
  TextColumn get goldInputUnit => text().nullable()();
  TextColumn get goldPriceUnit => text().nullable()();
  TextColumn get tomanRateDecimal => text().nullable()();
  IntColumn get totalToman => integer().nullable()();
  IntColumn get dealAtMicros => integer()();
  TextColumn get status => text()();
  TextColumn get note => text().nullable()();
  TextColumn get createdBy => text()();
  IntColumn get createdAtMicros => integer()();
  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalSettlementRow')
class ZarSettlements extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get dealId => text().nullable().references(
    ZarDeals,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get personId => text().references(ZarPeople, #id)();
  TextColumn get direction => text()();
  TextColumn get assetType => text()();
  TextColumn get goldDecimal => text().nullable()();
  TextColumn get goldUnit => text().nullable()();
  TextColumn get goldPurity => text().nullable()();
  TextColumn get currencyCode => text().nullable()();
  IntColumn get currencyMinorUnits => integer().nullable()();
  IntColumn get currencyMinorUnitScale => integer().nullable()();
  IntColumn get scheduledAtMicros => integer()();
  BoolColumn get hasTime => boolean()();
  TextColumn get status => text()();
  IntColumn get snoozedUntilMicros => integer().nullable()();
  IntColumn get completedAtMicros => integer().nullable()();
  TextColumn get completedBy => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdBy => text()();
  IntColumn get createdAtMicros => integer()();
  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalReminderRuleRow')
class ZarReminderRules extends Table {
  TextColumn get settlementId =>
      text().references(ZarSettlements, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  IntColumn get position => integer()();
  TextColumn get type => text()();
  IntColumn get minutesBefore => integer().nullable()();
  IntColumn get customAtMicros => integer().nullable()();
  BoolColumn get enabled => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {settlementId, ruleId};
}

@DataClassName('LocalMetadataRow')
class ZarLocalMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    ZarPeople,
    ZarDeals,
    ZarSettlements,
    ZarReminderRules,
    ZarLocalMetadata,
  ],
)
class ZarLocalDatabase extends _$ZarLocalDatabase {
  ZarLocalDatabase(super.executor);

  ZarLocalDatabase.defaults() : super(driftDatabase(name: 'zar_plus_local'));

  static const currentSchemaVersion = 5;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(zarLocalMetadata).insert(
        ZarLocalMetadataCompanion.insert(
          key: 'domain_schema_version',
          value: '5',
        ),
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(zarDeals, zarDeals.pricingKind);
        await migrator.addColumn(zarDeals, zarDeals.goldFineness);
        await migrator.addColumn(zarDeals, zarDeals.tomanRateDecimal);
        await migrator.addColumn(zarDeals, zarDeals.totalToman);
        await (update(zarLocalMetadata)
              ..where((row) => row.key.equals('domain_schema_version')))
            .write(const ZarLocalMetadataCompanion(value: Value('2')));
      }
      if (from < 3) {
        await migrator.addColumn(zarDeals, zarDeals.goldInputDecimal);
        await migrator.addColumn(zarDeals, zarDeals.goldInputUnit);
        await migrator.addColumn(zarDeals, zarDeals.goldPriceUnit);
        final oldGoldDeals = await (select(
          zarDeals,
        )..where((row) => row.assetType.equals(ZarAssetType.gold.name))).get();
        for (final row in oldGoldDeals) {
          final originalDecimal = row.goldDecimal;
          final originalUnitName = row.goldUnit;
          if (originalDecimal == null || originalUnitName == null) continue;
          final originalUnit = ZarGoldUnit.values.byName(originalUnitName);
          if (originalUnit != ZarGoldUnit.gram &&
              originalUnit != ZarGoldUnit.mesghal) {
            continue;
          }
          await (update(
            zarDeals,
          )..where((deal) => deal.id.equals(row.id))).write(
            ZarDealsCompanion(
              goldDecimal: Value(
                zarGoldWeightInGrams(originalDecimal, originalUnit),
              ),
              goldUnit: Value(ZarGoldUnit.gram.name),
              goldInputDecimal: Value(originalDecimal),
              goldInputUnit: Value(originalUnit.name),
              goldPriceUnit: row.pricingKind == 'gold'
                  ? Value(ZarGoldUnit.gram.name)
                  : const Value.absent(),
            ),
          );
        }
        await (update(zarLocalMetadata)
              ..where((row) => row.key.equals('domain_schema_version')))
            .write(const ZarLocalMetadataCompanion(value: Value('3')));
      }
      if (from < 4) {
        await migrator.addColumn(zarDeals, zarDeals.goldFinenessDecimal);
        await customStatement(
          'UPDATE zar_deals SET gold_fineness_decimal = '
          'CAST(gold_fineness AS TEXT) WHERE gold_fineness IS NOT NULL',
        );
        await (update(zarLocalMetadata)
              ..where((row) => row.key.equals('domain_schema_version')))
            .write(const ZarLocalMetadataCompanion(value: Value('4')));
      }
      if (from < 5) {
        await migrator.addColumn(zarDeals, zarDeals.goldPriceReferenceFineness);
        await customStatement(
          'UPDATE zar_deals SET gold_price_reference_fineness = '
          'gold_fineness_decimal WHERE pricing_kind = \'gold\'',
        );
        await (update(zarLocalMetadata)
              ..where((row) => row.key.equals('domain_schema_version')))
            .write(const ZarLocalMetadataCompanion(value: Value('5')));
      }
      if (to > currentSchemaVersion) {
        throw StateError(
          'Unsupported ZAR+ local database migration from $from to $to.',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.versionNow > currentSchemaVersion) {
        throw StateError('This ZAR+ database was created by a newer app.');
      }
    },
  );

  Future<void> ensureReady() async {
    await (select(zarLocalMetadata)..limit(1)).get();
  }
}
