import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(zarLocalMetadata).insert(
        ZarLocalMetadataCompanion.insert(
          key: 'domain_schema_version',
          value: '1',
        ),
      );
    },
    onUpgrade: (migrator, from, to) async {
      // Each future schema change must have an explicit, transactional
      // migration. Never delete or recreate a user's database implicitly.
      throw StateError(
        'Unsupported ZAR+ local database migration from $from to $to.',
      );
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
