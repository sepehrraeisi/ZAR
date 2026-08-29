// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zar_local_database.dart';

// ignore_for_file: type=lint
class $ZarPeopleTable extends ZarPeople
    with TableInfo<$ZarPeopleTable, LocalPersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZarPeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    phone,
    note,
    archived,
    createdAtMicros,
    updatedAtMicros,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zar_people';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $ZarPeopleTable createAlias(String alias) {
    return $ZarPeopleTable(attachedDatabase, alias);
  }
}

class LocalPersonRow extends DataClass implements Insertable<LocalPersonRow> {
  final String id;
  final String displayName;
  final String? phone;
  final String? note;
  final bool archived;
  final int createdAtMicros;
  final int updatedAtMicros;
  final String createdBy;
  const LocalPersonRow({
    required this.id,
    required this.displayName,
    this.phone,
    this.note,
    required this.archived,
    required this.createdAtMicros,
    required this.updatedAtMicros,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  ZarPeopleCompanion toCompanion(bool nullToAbsent) {
    return ZarPeopleCompanion(
      id: Value(id),
      displayName: Value(displayName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      archived: Value(archived),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
      createdBy: Value(createdBy),
    );
  }

  factory LocalPersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPersonRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      phone: serializer.fromJson<String?>(json['phone']),
      note: serializer.fromJson<String?>(json['note']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'phone': serializer.toJson<String?>(phone),
      'note': serializer.toJson<String?>(note),
      'archived': serializer.toJson<bool>(archived),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  LocalPersonRow copyWith({
    String? id,
    String? displayName,
    Value<String?> phone = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? archived,
    int? createdAtMicros,
    int? updatedAtMicros,
    String? createdBy,
  }) => LocalPersonRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    phone: phone.present ? phone.value : this.phone,
    note: note.present ? note.value : this.note,
    archived: archived ?? this.archived,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    createdBy: createdBy ?? this.createdBy,
  );
  LocalPersonRow copyWithCompanion(ZarPeopleCompanion data) {
    return LocalPersonRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      phone: data.phone.present ? data.phone.value : this.phone,
      note: data.note.present ? data.note.value : this.note,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPersonRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    phone,
    note,
    archived,
    createdAtMicros,
    updatedAtMicros,
    createdBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPersonRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.phone == this.phone &&
          other.note == this.note &&
          other.archived == this.archived &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros &&
          other.createdBy == this.createdBy);
}

class ZarPeopleCompanion extends UpdateCompanion<LocalPersonRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> phone;
  final Value<String?> note;
  final Value<bool> archived;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<String> createdBy;
  final Value<int> rowid;
  const ZarPeopleCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZarPeopleCompanion.insert({
    required String id,
    required String displayName,
    this.phone = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros),
       createdBy = Value(createdBy);
  static Insertable<LocalPersonRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? phone,
    Expression<String>? note,
    Expression<bool>? archived,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (note != null) 'note': note,
      if (archived != null) 'archived': archived,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZarPeopleCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String?>? phone,
    Value<String?>? note,
    Value<bool>? archived,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return ZarPeopleCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      archived: archived ?? this.archived,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZarPeopleCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZarDealsTable extends ZarDeals
    with TableInfo<$ZarDealsTable, LocalDealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZarDealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES zar_people (id)',
    ),
  );
  static const VerificationMeta _assetTypeMeta = const VerificationMeta(
    'assetType',
  );
  @override
  late final GeneratedColumn<String> assetType = GeneratedColumn<String>(
    'asset_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goldDecimalMeta = const VerificationMeta(
    'goldDecimal',
  );
  @override
  late final GeneratedColumn<String> goldDecimal = GeneratedColumn<String>(
    'gold_decimal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldUnitMeta = const VerificationMeta(
    'goldUnit',
  );
  @override
  late final GeneratedColumn<String> goldUnit = GeneratedColumn<String>(
    'gold_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldPurityMeta = const VerificationMeta(
    'goldPurity',
  );
  @override
  late final GeneratedColumn<String> goldPurity = GeneratedColumn<String>(
    'gold_purity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMinorUnitsMeta =
      const VerificationMeta('currencyMinorUnits');
  @override
  late final GeneratedColumn<int> currencyMinorUnits = GeneratedColumn<int>(
    'currency_minor_units',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMinorUnitScaleMeta =
      const VerificationMeta('currencyMinorUnitScale');
  @override
  late final GeneratedColumn<int> currencyMinorUnitScale = GeneratedColumn<int>(
    'currency_minor_unit_scale',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dealAtMicrosMeta = const VerificationMeta(
    'dealAtMicros',
  );
  @override
  late final GeneratedColumn<int> dealAtMicros = GeneratedColumn<int>(
    'deal_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    type,
    personId,
    assetType,
    goldDecimal,
    goldUnit,
    goldPurity,
    currencyCode,
    currencyMinorUnits,
    currencyMinorUnitScale,
    dealAtMicros,
    status,
    note,
    createdBy,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zar_deals';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDealRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('asset_type')) {
      context.handle(
        _assetTypeMeta,
        assetType.isAcceptableOrUnknown(data['asset_type']!, _assetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_assetTypeMeta);
    }
    if (data.containsKey('gold_decimal')) {
      context.handle(
        _goldDecimalMeta,
        goldDecimal.isAcceptableOrUnknown(
          data['gold_decimal']!,
          _goldDecimalMeta,
        ),
      );
    }
    if (data.containsKey('gold_unit')) {
      context.handle(
        _goldUnitMeta,
        goldUnit.isAcceptableOrUnknown(data['gold_unit']!, _goldUnitMeta),
      );
    }
    if (data.containsKey('gold_purity')) {
      context.handle(
        _goldPurityMeta,
        goldPurity.isAcceptableOrUnknown(data['gold_purity']!, _goldPurityMeta),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('currency_minor_units')) {
      context.handle(
        _currencyMinorUnitsMeta,
        currencyMinorUnits.isAcceptableOrUnknown(
          data['currency_minor_units']!,
          _currencyMinorUnitsMeta,
        ),
      );
    }
    if (data.containsKey('currency_minor_unit_scale')) {
      context.handle(
        _currencyMinorUnitScaleMeta,
        currencyMinorUnitScale.isAcceptableOrUnknown(
          data['currency_minor_unit_scale']!,
          _currencyMinorUnitScaleMeta,
        ),
      );
    }
    if (data.containsKey('deal_at_micros')) {
      context.handle(
        _dealAtMicrosMeta,
        dealAtMicros.isAcceptableOrUnknown(
          data['deal_at_micros']!,
          _dealAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dealAtMicrosMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDealRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      assetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_type'],
      )!,
      goldDecimal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_decimal'],
      ),
      goldUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_unit'],
      ),
      goldPurity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_purity'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      currencyMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}currency_minor_units'],
      ),
      currencyMinorUnitScale: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}currency_minor_unit_scale'],
      ),
      dealAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deal_at_micros'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $ZarDealsTable createAlias(String alias) {
    return $ZarDealsTable(attachedDatabase, alias);
  }
}

class LocalDealRow extends DataClass implements Insertable<LocalDealRow> {
  final String id;
  final String businessId;
  final String type;
  final String personId;
  final String assetType;
  final String? goldDecimal;
  final String? goldUnit;
  final String? goldPurity;
  final String? currencyCode;
  final int? currencyMinorUnits;
  final int? currencyMinorUnitScale;
  final int dealAtMicros;
  final String status;
  final String? note;
  final String createdBy;
  final int createdAtMicros;
  final int updatedAtMicros;
  const LocalDealRow({
    required this.id,
    required this.businessId,
    required this.type,
    required this.personId,
    required this.assetType,
    this.goldDecimal,
    this.goldUnit,
    this.goldPurity,
    this.currencyCode,
    this.currencyMinorUnits,
    this.currencyMinorUnitScale,
    required this.dealAtMicros,
    required this.status,
    this.note,
    required this.createdBy,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['type'] = Variable<String>(type);
    map['person_id'] = Variable<String>(personId);
    map['asset_type'] = Variable<String>(assetType);
    if (!nullToAbsent || goldDecimal != null) {
      map['gold_decimal'] = Variable<String>(goldDecimal);
    }
    if (!nullToAbsent || goldUnit != null) {
      map['gold_unit'] = Variable<String>(goldUnit);
    }
    if (!nullToAbsent || goldPurity != null) {
      map['gold_purity'] = Variable<String>(goldPurity);
    }
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || currencyMinorUnits != null) {
      map['currency_minor_units'] = Variable<int>(currencyMinorUnits);
    }
    if (!nullToAbsent || currencyMinorUnitScale != null) {
      map['currency_minor_unit_scale'] = Variable<int>(currencyMinorUnitScale);
    }
    map['deal_at_micros'] = Variable<int>(dealAtMicros);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  ZarDealsCompanion toCompanion(bool nullToAbsent) {
    return ZarDealsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      type: Value(type),
      personId: Value(personId),
      assetType: Value(assetType),
      goldDecimal: goldDecimal == null && nullToAbsent
          ? const Value.absent()
          : Value(goldDecimal),
      goldUnit: goldUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(goldUnit),
      goldPurity: goldPurity == null && nullToAbsent
          ? const Value.absent()
          : Value(goldPurity),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      currencyMinorUnits: currencyMinorUnits == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyMinorUnits),
      currencyMinorUnitScale: currencyMinorUnitScale == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyMinorUnitScale),
      dealAtMicros: Value(dealAtMicros),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdBy: Value(createdBy),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory LocalDealRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDealRow(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      type: serializer.fromJson<String>(json['type']),
      personId: serializer.fromJson<String>(json['personId']),
      assetType: serializer.fromJson<String>(json['assetType']),
      goldDecimal: serializer.fromJson<String?>(json['goldDecimal']),
      goldUnit: serializer.fromJson<String?>(json['goldUnit']),
      goldPurity: serializer.fromJson<String?>(json['goldPurity']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      currencyMinorUnits: serializer.fromJson<int?>(json['currencyMinorUnits']),
      currencyMinorUnitScale: serializer.fromJson<int?>(
        json['currencyMinorUnitScale'],
      ),
      dealAtMicros: serializer.fromJson<int>(json['dealAtMicros']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String?>(json['note']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'type': serializer.toJson<String>(type),
      'personId': serializer.toJson<String>(personId),
      'assetType': serializer.toJson<String>(assetType),
      'goldDecimal': serializer.toJson<String?>(goldDecimal),
      'goldUnit': serializer.toJson<String?>(goldUnit),
      'goldPurity': serializer.toJson<String?>(goldPurity),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'currencyMinorUnits': serializer.toJson<int?>(currencyMinorUnits),
      'currencyMinorUnitScale': serializer.toJson<int?>(currencyMinorUnitScale),
      'dealAtMicros': serializer.toJson<int>(dealAtMicros),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String?>(note),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  LocalDealRow copyWith({
    String? id,
    String? businessId,
    String? type,
    String? personId,
    String? assetType,
    Value<String?> goldDecimal = const Value.absent(),
    Value<String?> goldUnit = const Value.absent(),
    Value<String?> goldPurity = const Value.absent(),
    Value<String?> currencyCode = const Value.absent(),
    Value<int?> currencyMinorUnits = const Value.absent(),
    Value<int?> currencyMinorUnitScale = const Value.absent(),
    int? dealAtMicros,
    String? status,
    Value<String?> note = const Value.absent(),
    String? createdBy,
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => LocalDealRow(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    type: type ?? this.type,
    personId: personId ?? this.personId,
    assetType: assetType ?? this.assetType,
    goldDecimal: goldDecimal.present ? goldDecimal.value : this.goldDecimal,
    goldUnit: goldUnit.present ? goldUnit.value : this.goldUnit,
    goldPurity: goldPurity.present ? goldPurity.value : this.goldPurity,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    currencyMinorUnits: currencyMinorUnits.present
        ? currencyMinorUnits.value
        : this.currencyMinorUnits,
    currencyMinorUnitScale: currencyMinorUnitScale.present
        ? currencyMinorUnitScale.value
        : this.currencyMinorUnitScale,
    dealAtMicros: dealAtMicros ?? this.dealAtMicros,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    createdBy: createdBy ?? this.createdBy,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  LocalDealRow copyWithCompanion(ZarDealsCompanion data) {
    return LocalDealRow(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      type: data.type.present ? data.type.value : this.type,
      personId: data.personId.present ? data.personId.value : this.personId,
      assetType: data.assetType.present ? data.assetType.value : this.assetType,
      goldDecimal: data.goldDecimal.present
          ? data.goldDecimal.value
          : this.goldDecimal,
      goldUnit: data.goldUnit.present ? data.goldUnit.value : this.goldUnit,
      goldPurity: data.goldPurity.present
          ? data.goldPurity.value
          : this.goldPurity,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      currencyMinorUnits: data.currencyMinorUnits.present
          ? data.currencyMinorUnits.value
          : this.currencyMinorUnits,
      currencyMinorUnitScale: data.currencyMinorUnitScale.present
          ? data.currencyMinorUnitScale.value
          : this.currencyMinorUnitScale,
      dealAtMicros: data.dealAtMicros.present
          ? data.dealAtMicros.value
          : this.dealAtMicros,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDealRow(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('type: $type, ')
          ..write('personId: $personId, ')
          ..write('assetType: $assetType, ')
          ..write('goldDecimal: $goldDecimal, ')
          ..write('goldUnit: $goldUnit, ')
          ..write('goldPurity: $goldPurity, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currencyMinorUnits: $currencyMinorUnits, ')
          ..write('currencyMinorUnitScale: $currencyMinorUnitScale, ')
          ..write('dealAtMicros: $dealAtMicros, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    type,
    personId,
    assetType,
    goldDecimal,
    goldUnit,
    goldPurity,
    currencyCode,
    currencyMinorUnits,
    currencyMinorUnitScale,
    dealAtMicros,
    status,
    note,
    createdBy,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDealRow &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.type == this.type &&
          other.personId == this.personId &&
          other.assetType == this.assetType &&
          other.goldDecimal == this.goldDecimal &&
          other.goldUnit == this.goldUnit &&
          other.goldPurity == this.goldPurity &&
          other.currencyCode == this.currencyCode &&
          other.currencyMinorUnits == this.currencyMinorUnits &&
          other.currencyMinorUnitScale == this.currencyMinorUnitScale &&
          other.dealAtMicros == this.dealAtMicros &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdBy == this.createdBy &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class ZarDealsCompanion extends UpdateCompanion<LocalDealRow> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> type;
  final Value<String> personId;
  final Value<String> assetType;
  final Value<String?> goldDecimal;
  final Value<String?> goldUnit;
  final Value<String?> goldPurity;
  final Value<String?> currencyCode;
  final Value<int?> currencyMinorUnits;
  final Value<int?> currencyMinorUnitScale;
  final Value<int> dealAtMicros;
  final Value<String> status;
  final Value<String?> note;
  final Value<String> createdBy;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const ZarDealsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.type = const Value.absent(),
    this.personId = const Value.absent(),
    this.assetType = const Value.absent(),
    this.goldDecimal = const Value.absent(),
    this.goldUnit = const Value.absent(),
    this.goldPurity = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.currencyMinorUnits = const Value.absent(),
    this.currencyMinorUnitScale = const Value.absent(),
    this.dealAtMicros = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZarDealsCompanion.insert({
    required String id,
    required String businessId,
    required String type,
    required String personId,
    required String assetType,
    this.goldDecimal = const Value.absent(),
    this.goldUnit = const Value.absent(),
    this.goldPurity = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.currencyMinorUnits = const Value.absent(),
    this.currencyMinorUnitScale = const Value.absent(),
    required int dealAtMicros,
    required String status,
    this.note = const Value.absent(),
    required String createdBy,
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       type = Value(type),
       personId = Value(personId),
       assetType = Value(assetType),
       dealAtMicros = Value(dealAtMicros),
       status = Value(status),
       createdBy = Value(createdBy),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<LocalDealRow> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? type,
    Expression<String>? personId,
    Expression<String>? assetType,
    Expression<String>? goldDecimal,
    Expression<String>? goldUnit,
    Expression<String>? goldPurity,
    Expression<String>? currencyCode,
    Expression<int>? currencyMinorUnits,
    Expression<int>? currencyMinorUnitScale,
    Expression<int>? dealAtMicros,
    Expression<String>? status,
    Expression<String>? note,
    Expression<String>? createdBy,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (type != null) 'type': type,
      if (personId != null) 'person_id': personId,
      if (assetType != null) 'asset_type': assetType,
      if (goldDecimal != null) 'gold_decimal': goldDecimal,
      if (goldUnit != null) 'gold_unit': goldUnit,
      if (goldPurity != null) 'gold_purity': goldPurity,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (currencyMinorUnits != null)
        'currency_minor_units': currencyMinorUnits,
      if (currencyMinorUnitScale != null)
        'currency_minor_unit_scale': currencyMinorUnitScale,
      if (dealAtMicros != null) 'deal_at_micros': dealAtMicros,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZarDealsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? type,
    Value<String>? personId,
    Value<String>? assetType,
    Value<String?>? goldDecimal,
    Value<String?>? goldUnit,
    Value<String?>? goldPurity,
    Value<String?>? currencyCode,
    Value<int?>? currencyMinorUnits,
    Value<int?>? currencyMinorUnitScale,
    Value<int>? dealAtMicros,
    Value<String>? status,
    Value<String?>? note,
    Value<String>? createdBy,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return ZarDealsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      personId: personId ?? this.personId,
      assetType: assetType ?? this.assetType,
      goldDecimal: goldDecimal ?? this.goldDecimal,
      goldUnit: goldUnit ?? this.goldUnit,
      goldPurity: goldPurity ?? this.goldPurity,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyMinorUnits: currencyMinorUnits ?? this.currencyMinorUnits,
      currencyMinorUnitScale:
          currencyMinorUnitScale ?? this.currencyMinorUnitScale,
      dealAtMicros: dealAtMicros ?? this.dealAtMicros,
      status: status ?? this.status,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (assetType.present) {
      map['asset_type'] = Variable<String>(assetType.value);
    }
    if (goldDecimal.present) {
      map['gold_decimal'] = Variable<String>(goldDecimal.value);
    }
    if (goldUnit.present) {
      map['gold_unit'] = Variable<String>(goldUnit.value);
    }
    if (goldPurity.present) {
      map['gold_purity'] = Variable<String>(goldPurity.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (currencyMinorUnits.present) {
      map['currency_minor_units'] = Variable<int>(currencyMinorUnits.value);
    }
    if (currencyMinorUnitScale.present) {
      map['currency_minor_unit_scale'] = Variable<int>(
        currencyMinorUnitScale.value,
      );
    }
    if (dealAtMicros.present) {
      map['deal_at_micros'] = Variable<int>(dealAtMicros.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZarDealsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('type: $type, ')
          ..write('personId: $personId, ')
          ..write('assetType: $assetType, ')
          ..write('goldDecimal: $goldDecimal, ')
          ..write('goldUnit: $goldUnit, ')
          ..write('goldPurity: $goldPurity, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currencyMinorUnits: $currencyMinorUnits, ')
          ..write('currencyMinorUnitScale: $currencyMinorUnitScale, ')
          ..write('dealAtMicros: $dealAtMicros, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZarSettlementsTable extends ZarSettlements
    with TableInfo<$ZarSettlementsTable, LocalSettlementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZarSettlementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dealIdMeta = const VerificationMeta('dealId');
  @override
  late final GeneratedColumn<String> dealId = GeneratedColumn<String>(
    'deal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES zar_deals (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES zar_people (id)',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetTypeMeta = const VerificationMeta(
    'assetType',
  );
  @override
  late final GeneratedColumn<String> assetType = GeneratedColumn<String>(
    'asset_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goldDecimalMeta = const VerificationMeta(
    'goldDecimal',
  );
  @override
  late final GeneratedColumn<String> goldDecimal = GeneratedColumn<String>(
    'gold_decimal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldUnitMeta = const VerificationMeta(
    'goldUnit',
  );
  @override
  late final GeneratedColumn<String> goldUnit = GeneratedColumn<String>(
    'gold_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldPurityMeta = const VerificationMeta(
    'goldPurity',
  );
  @override
  late final GeneratedColumn<String> goldPurity = GeneratedColumn<String>(
    'gold_purity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMinorUnitsMeta =
      const VerificationMeta('currencyMinorUnits');
  @override
  late final GeneratedColumn<int> currencyMinorUnits = GeneratedColumn<int>(
    'currency_minor_units',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMinorUnitScaleMeta =
      const VerificationMeta('currencyMinorUnitScale');
  @override
  late final GeneratedColumn<int> currencyMinorUnitScale = GeneratedColumn<int>(
    'currency_minor_unit_scale',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledAtMicrosMeta = const VerificationMeta(
    'scheduledAtMicros',
  );
  @override
  late final GeneratedColumn<int> scheduledAtMicros = GeneratedColumn<int>(
    'scheduled_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasTimeMeta = const VerificationMeta(
    'hasTime',
  );
  @override
  late final GeneratedColumn<bool> hasTime = GeneratedColumn<bool>(
    'has_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_time" IN (0, 1))',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozedUntilMicrosMeta =
      const VerificationMeta('snoozedUntilMicros');
  @override
  late final GeneratedColumn<int> snoozedUntilMicros = GeneratedColumn<int>(
    'snoozed_until_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMicrosMeta = const VerificationMeta(
    'completedAtMicros',
  );
  @override
  late final GeneratedColumn<int> completedAtMicros = GeneratedColumn<int>(
    'completed_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedByMeta = const VerificationMeta(
    'completedBy',
  );
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
    'completed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    dealId,
    personId,
    direction,
    assetType,
    goldDecimal,
    goldUnit,
    goldPurity,
    currencyCode,
    currencyMinorUnits,
    currencyMinorUnitScale,
    scheduledAtMicros,
    hasTime,
    status,
    snoozedUntilMicros,
    completedAtMicros,
    completedBy,
    note,
    createdBy,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zar_settlements';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSettlementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('deal_id')) {
      context.handle(
        _dealIdMeta,
        dealId.isAcceptableOrUnknown(data['deal_id']!, _dealIdMeta),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('asset_type')) {
      context.handle(
        _assetTypeMeta,
        assetType.isAcceptableOrUnknown(data['asset_type']!, _assetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_assetTypeMeta);
    }
    if (data.containsKey('gold_decimal')) {
      context.handle(
        _goldDecimalMeta,
        goldDecimal.isAcceptableOrUnknown(
          data['gold_decimal']!,
          _goldDecimalMeta,
        ),
      );
    }
    if (data.containsKey('gold_unit')) {
      context.handle(
        _goldUnitMeta,
        goldUnit.isAcceptableOrUnknown(data['gold_unit']!, _goldUnitMeta),
      );
    }
    if (data.containsKey('gold_purity')) {
      context.handle(
        _goldPurityMeta,
        goldPurity.isAcceptableOrUnknown(data['gold_purity']!, _goldPurityMeta),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('currency_minor_units')) {
      context.handle(
        _currencyMinorUnitsMeta,
        currencyMinorUnits.isAcceptableOrUnknown(
          data['currency_minor_units']!,
          _currencyMinorUnitsMeta,
        ),
      );
    }
    if (data.containsKey('currency_minor_unit_scale')) {
      context.handle(
        _currencyMinorUnitScaleMeta,
        currencyMinorUnitScale.isAcceptableOrUnknown(
          data['currency_minor_unit_scale']!,
          _currencyMinorUnitScaleMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_at_micros')) {
      context.handle(
        _scheduledAtMicrosMeta,
        scheduledAtMicros.isAcceptableOrUnknown(
          data['scheduled_at_micros']!,
          _scheduledAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtMicrosMeta);
    }
    if (data.containsKey('has_time')) {
      context.handle(
        _hasTimeMeta,
        hasTime.isAcceptableOrUnknown(data['has_time']!, _hasTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_hasTimeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('snoozed_until_micros')) {
      context.handle(
        _snoozedUntilMicrosMeta,
        snoozedUntilMicros.isAcceptableOrUnknown(
          data['snoozed_until_micros']!,
          _snoozedUntilMicrosMeta,
        ),
      );
    }
    if (data.containsKey('completed_at_micros')) {
      context.handle(
        _completedAtMicrosMeta,
        completedAtMicros.isAcceptableOrUnknown(
          data['completed_at_micros']!,
          _completedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('completed_by')) {
      context.handle(
        _completedByMeta,
        completedBy.isAcceptableOrUnknown(
          data['completed_by']!,
          _completedByMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSettlementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSettlementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      dealId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deal_id'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      assetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_type'],
      )!,
      goldDecimal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_decimal'],
      ),
      goldUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_unit'],
      ),
      goldPurity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_purity'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      currencyMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}currency_minor_units'],
      ),
      currencyMinorUnitScale: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}currency_minor_unit_scale'],
      ),
      scheduledAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at_micros'],
      )!,
      hasTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_time'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      snoozedUntilMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until_micros'],
      ),
      completedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_micros'],
      ),
      completedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $ZarSettlementsTable createAlias(String alias) {
    return $ZarSettlementsTable(attachedDatabase, alias);
  }
}

class LocalSettlementRow extends DataClass
    implements Insertable<LocalSettlementRow> {
  final String id;
  final String businessId;
  final String? dealId;
  final String personId;
  final String direction;
  final String assetType;
  final String? goldDecimal;
  final String? goldUnit;
  final String? goldPurity;
  final String? currencyCode;
  final int? currencyMinorUnits;
  final int? currencyMinorUnitScale;
  final int scheduledAtMicros;
  final bool hasTime;
  final String status;
  final int? snoozedUntilMicros;
  final int? completedAtMicros;
  final String? completedBy;
  final String? note;
  final String createdBy;
  final int createdAtMicros;
  final int updatedAtMicros;
  const LocalSettlementRow({
    required this.id,
    required this.businessId,
    this.dealId,
    required this.personId,
    required this.direction,
    required this.assetType,
    this.goldDecimal,
    this.goldUnit,
    this.goldPurity,
    this.currencyCode,
    this.currencyMinorUnits,
    this.currencyMinorUnitScale,
    required this.scheduledAtMicros,
    required this.hasTime,
    required this.status,
    this.snoozedUntilMicros,
    this.completedAtMicros,
    this.completedBy,
    this.note,
    required this.createdBy,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    if (!nullToAbsent || dealId != null) {
      map['deal_id'] = Variable<String>(dealId);
    }
    map['person_id'] = Variable<String>(personId);
    map['direction'] = Variable<String>(direction);
    map['asset_type'] = Variable<String>(assetType);
    if (!nullToAbsent || goldDecimal != null) {
      map['gold_decimal'] = Variable<String>(goldDecimal);
    }
    if (!nullToAbsent || goldUnit != null) {
      map['gold_unit'] = Variable<String>(goldUnit);
    }
    if (!nullToAbsent || goldPurity != null) {
      map['gold_purity'] = Variable<String>(goldPurity);
    }
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || currencyMinorUnits != null) {
      map['currency_minor_units'] = Variable<int>(currencyMinorUnits);
    }
    if (!nullToAbsent || currencyMinorUnitScale != null) {
      map['currency_minor_unit_scale'] = Variable<int>(currencyMinorUnitScale);
    }
    map['scheduled_at_micros'] = Variable<int>(scheduledAtMicros);
    map['has_time'] = Variable<bool>(hasTime);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || snoozedUntilMicros != null) {
      map['snoozed_until_micros'] = Variable<int>(snoozedUntilMicros);
    }
    if (!nullToAbsent || completedAtMicros != null) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  ZarSettlementsCompanion toCompanion(bool nullToAbsent) {
    return ZarSettlementsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      dealId: dealId == null && nullToAbsent
          ? const Value.absent()
          : Value(dealId),
      personId: Value(personId),
      direction: Value(direction),
      assetType: Value(assetType),
      goldDecimal: goldDecimal == null && nullToAbsent
          ? const Value.absent()
          : Value(goldDecimal),
      goldUnit: goldUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(goldUnit),
      goldPurity: goldPurity == null && nullToAbsent
          ? const Value.absent()
          : Value(goldPurity),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      currencyMinorUnits: currencyMinorUnits == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyMinorUnits),
      currencyMinorUnitScale: currencyMinorUnitScale == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyMinorUnitScale),
      scheduledAtMicros: Value(scheduledAtMicros),
      hasTime: Value(hasTime),
      status: Value(status),
      snoozedUntilMicros: snoozedUntilMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntilMicros),
      completedAtMicros: completedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMicros),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdBy: Value(createdBy),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory LocalSettlementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSettlementRow(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      dealId: serializer.fromJson<String?>(json['dealId']),
      personId: serializer.fromJson<String>(json['personId']),
      direction: serializer.fromJson<String>(json['direction']),
      assetType: serializer.fromJson<String>(json['assetType']),
      goldDecimal: serializer.fromJson<String?>(json['goldDecimal']),
      goldUnit: serializer.fromJson<String?>(json['goldUnit']),
      goldPurity: serializer.fromJson<String?>(json['goldPurity']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      currencyMinorUnits: serializer.fromJson<int?>(json['currencyMinorUnits']),
      currencyMinorUnitScale: serializer.fromJson<int?>(
        json['currencyMinorUnitScale'],
      ),
      scheduledAtMicros: serializer.fromJson<int>(json['scheduledAtMicros']),
      hasTime: serializer.fromJson<bool>(json['hasTime']),
      status: serializer.fromJson<String>(json['status']),
      snoozedUntilMicros: serializer.fromJson<int?>(json['snoozedUntilMicros']),
      completedAtMicros: serializer.fromJson<int?>(json['completedAtMicros']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      note: serializer.fromJson<String?>(json['note']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'dealId': serializer.toJson<String?>(dealId),
      'personId': serializer.toJson<String>(personId),
      'direction': serializer.toJson<String>(direction),
      'assetType': serializer.toJson<String>(assetType),
      'goldDecimal': serializer.toJson<String?>(goldDecimal),
      'goldUnit': serializer.toJson<String?>(goldUnit),
      'goldPurity': serializer.toJson<String?>(goldPurity),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'currencyMinorUnits': serializer.toJson<int?>(currencyMinorUnits),
      'currencyMinorUnitScale': serializer.toJson<int?>(currencyMinorUnitScale),
      'scheduledAtMicros': serializer.toJson<int>(scheduledAtMicros),
      'hasTime': serializer.toJson<bool>(hasTime),
      'status': serializer.toJson<String>(status),
      'snoozedUntilMicros': serializer.toJson<int?>(snoozedUntilMicros),
      'completedAtMicros': serializer.toJson<int?>(completedAtMicros),
      'completedBy': serializer.toJson<String?>(completedBy),
      'note': serializer.toJson<String?>(note),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  LocalSettlementRow copyWith({
    String? id,
    String? businessId,
    Value<String?> dealId = const Value.absent(),
    String? personId,
    String? direction,
    String? assetType,
    Value<String?> goldDecimal = const Value.absent(),
    Value<String?> goldUnit = const Value.absent(),
    Value<String?> goldPurity = const Value.absent(),
    Value<String?> currencyCode = const Value.absent(),
    Value<int?> currencyMinorUnits = const Value.absent(),
    Value<int?> currencyMinorUnitScale = const Value.absent(),
    int? scheduledAtMicros,
    bool? hasTime,
    String? status,
    Value<int?> snoozedUntilMicros = const Value.absent(),
    Value<int?> completedAtMicros = const Value.absent(),
    Value<String?> completedBy = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? createdBy,
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => LocalSettlementRow(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    dealId: dealId.present ? dealId.value : this.dealId,
    personId: personId ?? this.personId,
    direction: direction ?? this.direction,
    assetType: assetType ?? this.assetType,
    goldDecimal: goldDecimal.present ? goldDecimal.value : this.goldDecimal,
    goldUnit: goldUnit.present ? goldUnit.value : this.goldUnit,
    goldPurity: goldPurity.present ? goldPurity.value : this.goldPurity,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    currencyMinorUnits: currencyMinorUnits.present
        ? currencyMinorUnits.value
        : this.currencyMinorUnits,
    currencyMinorUnitScale: currencyMinorUnitScale.present
        ? currencyMinorUnitScale.value
        : this.currencyMinorUnitScale,
    scheduledAtMicros: scheduledAtMicros ?? this.scheduledAtMicros,
    hasTime: hasTime ?? this.hasTime,
    status: status ?? this.status,
    snoozedUntilMicros: snoozedUntilMicros.present
        ? snoozedUntilMicros.value
        : this.snoozedUntilMicros,
    completedAtMicros: completedAtMicros.present
        ? completedAtMicros.value
        : this.completedAtMicros,
    completedBy: completedBy.present ? completedBy.value : this.completedBy,
    note: note.present ? note.value : this.note,
    createdBy: createdBy ?? this.createdBy,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  LocalSettlementRow copyWithCompanion(ZarSettlementsCompanion data) {
    return LocalSettlementRow(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      dealId: data.dealId.present ? data.dealId.value : this.dealId,
      personId: data.personId.present ? data.personId.value : this.personId,
      direction: data.direction.present ? data.direction.value : this.direction,
      assetType: data.assetType.present ? data.assetType.value : this.assetType,
      goldDecimal: data.goldDecimal.present
          ? data.goldDecimal.value
          : this.goldDecimal,
      goldUnit: data.goldUnit.present ? data.goldUnit.value : this.goldUnit,
      goldPurity: data.goldPurity.present
          ? data.goldPurity.value
          : this.goldPurity,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      currencyMinorUnits: data.currencyMinorUnits.present
          ? data.currencyMinorUnits.value
          : this.currencyMinorUnits,
      currencyMinorUnitScale: data.currencyMinorUnitScale.present
          ? data.currencyMinorUnitScale.value
          : this.currencyMinorUnitScale,
      scheduledAtMicros: data.scheduledAtMicros.present
          ? data.scheduledAtMicros.value
          : this.scheduledAtMicros,
      hasTime: data.hasTime.present ? data.hasTime.value : this.hasTime,
      status: data.status.present ? data.status.value : this.status,
      snoozedUntilMicros: data.snoozedUntilMicros.present
          ? data.snoozedUntilMicros.value
          : this.snoozedUntilMicros,
      completedAtMicros: data.completedAtMicros.present
          ? data.completedAtMicros.value
          : this.completedAtMicros,
      completedBy: data.completedBy.present
          ? data.completedBy.value
          : this.completedBy,
      note: data.note.present ? data.note.value : this.note,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettlementRow(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('dealId: $dealId, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('assetType: $assetType, ')
          ..write('goldDecimal: $goldDecimal, ')
          ..write('goldUnit: $goldUnit, ')
          ..write('goldPurity: $goldPurity, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currencyMinorUnits: $currencyMinorUnits, ')
          ..write('currencyMinorUnitScale: $currencyMinorUnitScale, ')
          ..write('scheduledAtMicros: $scheduledAtMicros, ')
          ..write('hasTime: $hasTime, ')
          ..write('status: $status, ')
          ..write('snoozedUntilMicros: $snoozedUntilMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('completedBy: $completedBy, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    businessId,
    dealId,
    personId,
    direction,
    assetType,
    goldDecimal,
    goldUnit,
    goldPurity,
    currencyCode,
    currencyMinorUnits,
    currencyMinorUnitScale,
    scheduledAtMicros,
    hasTime,
    status,
    snoozedUntilMicros,
    completedAtMicros,
    completedBy,
    note,
    createdBy,
    createdAtMicros,
    updatedAtMicros,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSettlementRow &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.dealId == this.dealId &&
          other.personId == this.personId &&
          other.direction == this.direction &&
          other.assetType == this.assetType &&
          other.goldDecimal == this.goldDecimal &&
          other.goldUnit == this.goldUnit &&
          other.goldPurity == this.goldPurity &&
          other.currencyCode == this.currencyCode &&
          other.currencyMinorUnits == this.currencyMinorUnits &&
          other.currencyMinorUnitScale == this.currencyMinorUnitScale &&
          other.scheduledAtMicros == this.scheduledAtMicros &&
          other.hasTime == this.hasTime &&
          other.status == this.status &&
          other.snoozedUntilMicros == this.snoozedUntilMicros &&
          other.completedAtMicros == this.completedAtMicros &&
          other.completedBy == this.completedBy &&
          other.note == this.note &&
          other.createdBy == this.createdBy &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class ZarSettlementsCompanion extends UpdateCompanion<LocalSettlementRow> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String?> dealId;
  final Value<String> personId;
  final Value<String> direction;
  final Value<String> assetType;
  final Value<String?> goldDecimal;
  final Value<String?> goldUnit;
  final Value<String?> goldPurity;
  final Value<String?> currencyCode;
  final Value<int?> currencyMinorUnits;
  final Value<int?> currencyMinorUnitScale;
  final Value<int> scheduledAtMicros;
  final Value<bool> hasTime;
  final Value<String> status;
  final Value<int?> snoozedUntilMicros;
  final Value<int?> completedAtMicros;
  final Value<String?> completedBy;
  final Value<String?> note;
  final Value<String> createdBy;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const ZarSettlementsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.dealId = const Value.absent(),
    this.personId = const Value.absent(),
    this.direction = const Value.absent(),
    this.assetType = const Value.absent(),
    this.goldDecimal = const Value.absent(),
    this.goldUnit = const Value.absent(),
    this.goldPurity = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.currencyMinorUnits = const Value.absent(),
    this.currencyMinorUnitScale = const Value.absent(),
    this.scheduledAtMicros = const Value.absent(),
    this.hasTime = const Value.absent(),
    this.status = const Value.absent(),
    this.snoozedUntilMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZarSettlementsCompanion.insert({
    required String id,
    required String businessId,
    this.dealId = const Value.absent(),
    required String personId,
    required String direction,
    required String assetType,
    this.goldDecimal = const Value.absent(),
    this.goldUnit = const Value.absent(),
    this.goldPurity = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.currencyMinorUnits = const Value.absent(),
    this.currencyMinorUnitScale = const Value.absent(),
    required int scheduledAtMicros,
    required bool hasTime,
    required String status,
    this.snoozedUntilMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.note = const Value.absent(),
    required String createdBy,
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       personId = Value(personId),
       direction = Value(direction),
       assetType = Value(assetType),
       scheduledAtMicros = Value(scheduledAtMicros),
       hasTime = Value(hasTime),
       status = Value(status),
       createdBy = Value(createdBy),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<LocalSettlementRow> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? dealId,
    Expression<String>? personId,
    Expression<String>? direction,
    Expression<String>? assetType,
    Expression<String>? goldDecimal,
    Expression<String>? goldUnit,
    Expression<String>? goldPurity,
    Expression<String>? currencyCode,
    Expression<int>? currencyMinorUnits,
    Expression<int>? currencyMinorUnitScale,
    Expression<int>? scheduledAtMicros,
    Expression<bool>? hasTime,
    Expression<String>? status,
    Expression<int>? snoozedUntilMicros,
    Expression<int>? completedAtMicros,
    Expression<String>? completedBy,
    Expression<String>? note,
    Expression<String>? createdBy,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (dealId != null) 'deal_id': dealId,
      if (personId != null) 'person_id': personId,
      if (direction != null) 'direction': direction,
      if (assetType != null) 'asset_type': assetType,
      if (goldDecimal != null) 'gold_decimal': goldDecimal,
      if (goldUnit != null) 'gold_unit': goldUnit,
      if (goldPurity != null) 'gold_purity': goldPurity,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (currencyMinorUnits != null)
        'currency_minor_units': currencyMinorUnits,
      if (currencyMinorUnitScale != null)
        'currency_minor_unit_scale': currencyMinorUnitScale,
      if (scheduledAtMicros != null) 'scheduled_at_micros': scheduledAtMicros,
      if (hasTime != null) 'has_time': hasTime,
      if (status != null) 'status': status,
      if (snoozedUntilMicros != null)
        'snoozed_until_micros': snoozedUntilMicros,
      if (completedAtMicros != null) 'completed_at_micros': completedAtMicros,
      if (completedBy != null) 'completed_by': completedBy,
      if (note != null) 'note': note,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZarSettlementsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String?>? dealId,
    Value<String>? personId,
    Value<String>? direction,
    Value<String>? assetType,
    Value<String?>? goldDecimal,
    Value<String?>? goldUnit,
    Value<String?>? goldPurity,
    Value<String?>? currencyCode,
    Value<int?>? currencyMinorUnits,
    Value<int?>? currencyMinorUnitScale,
    Value<int>? scheduledAtMicros,
    Value<bool>? hasTime,
    Value<String>? status,
    Value<int?>? snoozedUntilMicros,
    Value<int?>? completedAtMicros,
    Value<String?>? completedBy,
    Value<String?>? note,
    Value<String>? createdBy,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return ZarSettlementsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      dealId: dealId ?? this.dealId,
      personId: personId ?? this.personId,
      direction: direction ?? this.direction,
      assetType: assetType ?? this.assetType,
      goldDecimal: goldDecimal ?? this.goldDecimal,
      goldUnit: goldUnit ?? this.goldUnit,
      goldPurity: goldPurity ?? this.goldPurity,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyMinorUnits: currencyMinorUnits ?? this.currencyMinorUnits,
      currencyMinorUnitScale:
          currencyMinorUnitScale ?? this.currencyMinorUnitScale,
      scheduledAtMicros: scheduledAtMicros ?? this.scheduledAtMicros,
      hasTime: hasTime ?? this.hasTime,
      status: status ?? this.status,
      snoozedUntilMicros: snoozedUntilMicros ?? this.snoozedUntilMicros,
      completedAtMicros: completedAtMicros ?? this.completedAtMicros,
      completedBy: completedBy ?? this.completedBy,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (dealId.present) {
      map['deal_id'] = Variable<String>(dealId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (assetType.present) {
      map['asset_type'] = Variable<String>(assetType.value);
    }
    if (goldDecimal.present) {
      map['gold_decimal'] = Variable<String>(goldDecimal.value);
    }
    if (goldUnit.present) {
      map['gold_unit'] = Variable<String>(goldUnit.value);
    }
    if (goldPurity.present) {
      map['gold_purity'] = Variable<String>(goldPurity.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (currencyMinorUnits.present) {
      map['currency_minor_units'] = Variable<int>(currencyMinorUnits.value);
    }
    if (currencyMinorUnitScale.present) {
      map['currency_minor_unit_scale'] = Variable<int>(
        currencyMinorUnitScale.value,
      );
    }
    if (scheduledAtMicros.present) {
      map['scheduled_at_micros'] = Variable<int>(scheduledAtMicros.value);
    }
    if (hasTime.present) {
      map['has_time'] = Variable<bool>(hasTime.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (snoozedUntilMicros.present) {
      map['snoozed_until_micros'] = Variable<int>(snoozedUntilMicros.value);
    }
    if (completedAtMicros.present) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZarSettlementsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('dealId: $dealId, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('assetType: $assetType, ')
          ..write('goldDecimal: $goldDecimal, ')
          ..write('goldUnit: $goldUnit, ')
          ..write('goldPurity: $goldPurity, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currencyMinorUnits: $currencyMinorUnits, ')
          ..write('currencyMinorUnitScale: $currencyMinorUnitScale, ')
          ..write('scheduledAtMicros: $scheduledAtMicros, ')
          ..write('hasTime: $hasTime, ')
          ..write('status: $status, ')
          ..write('snoozedUntilMicros: $snoozedUntilMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('completedBy: $completedBy, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZarReminderRulesTable extends ZarReminderRules
    with TableInfo<$ZarReminderRulesTable, LocalReminderRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZarReminderRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _settlementIdMeta = const VerificationMeta(
    'settlementId',
  );
  @override
  late final GeneratedColumn<String> settlementId = GeneratedColumn<String>(
    'settlement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES zar_settlements (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minutesBeforeMeta = const VerificationMeta(
    'minutesBefore',
  );
  @override
  late final GeneratedColumn<int> minutesBefore = GeneratedColumn<int>(
    'minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customAtMicrosMeta = const VerificationMeta(
    'customAtMicros',
  );
  @override
  late final GeneratedColumn<int> customAtMicros = GeneratedColumn<int>(
    'custom_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    settlementId,
    ruleId,
    position,
    type,
    minutesBefore,
    customAtMicros,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zar_reminder_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalReminderRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('settlement_id')) {
      context.handle(
        _settlementIdMeta,
        settlementId.isAcceptableOrUnknown(
          data['settlement_id']!,
          _settlementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_settlementIdMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('minutes_before')) {
      context.handle(
        _minutesBeforeMeta,
        minutesBefore.isAcceptableOrUnknown(
          data['minutes_before']!,
          _minutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('custom_at_micros')) {
      context.handle(
        _customAtMicrosMeta,
        customAtMicros.isAcceptableOrUnknown(
          data['custom_at_micros']!,
          _customAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {settlementId, ruleId};
  @override
  LocalReminderRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReminderRuleRow(
      settlementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settlement_id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      minutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes_before'],
      ),
      customAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_at_micros'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $ZarReminderRulesTable createAlias(String alias) {
    return $ZarReminderRulesTable(attachedDatabase, alias);
  }
}

class LocalReminderRuleRow extends DataClass
    implements Insertable<LocalReminderRuleRow> {
  final String settlementId;
  final String ruleId;
  final int position;
  final String type;
  final int? minutesBefore;
  final int? customAtMicros;
  final bool enabled;
  const LocalReminderRuleRow({
    required this.settlementId,
    required this.ruleId,
    required this.position,
    required this.type,
    this.minutesBefore,
    this.customAtMicros,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['settlement_id'] = Variable<String>(settlementId);
    map['rule_id'] = Variable<String>(ruleId);
    map['position'] = Variable<int>(position);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || minutesBefore != null) {
      map['minutes_before'] = Variable<int>(minutesBefore);
    }
    if (!nullToAbsent || customAtMicros != null) {
      map['custom_at_micros'] = Variable<int>(customAtMicros);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  ZarReminderRulesCompanion toCompanion(bool nullToAbsent) {
    return ZarReminderRulesCompanion(
      settlementId: Value(settlementId),
      ruleId: Value(ruleId),
      position: Value(position),
      type: Value(type),
      minutesBefore: minutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(minutesBefore),
      customAtMicros: customAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(customAtMicros),
      enabled: Value(enabled),
    );
  }

  factory LocalReminderRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReminderRuleRow(
      settlementId: serializer.fromJson<String>(json['settlementId']),
      ruleId: serializer.fromJson<String>(json['ruleId']),
      position: serializer.fromJson<int>(json['position']),
      type: serializer.fromJson<String>(json['type']),
      minutesBefore: serializer.fromJson<int?>(json['minutesBefore']),
      customAtMicros: serializer.fromJson<int?>(json['customAtMicros']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'settlementId': serializer.toJson<String>(settlementId),
      'ruleId': serializer.toJson<String>(ruleId),
      'position': serializer.toJson<int>(position),
      'type': serializer.toJson<String>(type),
      'minutesBefore': serializer.toJson<int?>(minutesBefore),
      'customAtMicros': serializer.toJson<int?>(customAtMicros),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  LocalReminderRuleRow copyWith({
    String? settlementId,
    String? ruleId,
    int? position,
    String? type,
    Value<int?> minutesBefore = const Value.absent(),
    Value<int?> customAtMicros = const Value.absent(),
    bool? enabled,
  }) => LocalReminderRuleRow(
    settlementId: settlementId ?? this.settlementId,
    ruleId: ruleId ?? this.ruleId,
    position: position ?? this.position,
    type: type ?? this.type,
    minutesBefore: minutesBefore.present
        ? minutesBefore.value
        : this.minutesBefore,
    customAtMicros: customAtMicros.present
        ? customAtMicros.value
        : this.customAtMicros,
    enabled: enabled ?? this.enabled,
  );
  LocalReminderRuleRow copyWithCompanion(ZarReminderRulesCompanion data) {
    return LocalReminderRuleRow(
      settlementId: data.settlementId.present
          ? data.settlementId.value
          : this.settlementId,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      position: data.position.present ? data.position.value : this.position,
      type: data.type.present ? data.type.value : this.type,
      minutesBefore: data.minutesBefore.present
          ? data.minutesBefore.value
          : this.minutesBefore,
      customAtMicros: data.customAtMicros.present
          ? data.customAtMicros.value
          : this.customAtMicros,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReminderRuleRow(')
          ..write('settlementId: $settlementId, ')
          ..write('ruleId: $ruleId, ')
          ..write('position: $position, ')
          ..write('type: $type, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('customAtMicros: $customAtMicros, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    settlementId,
    ruleId,
    position,
    type,
    minutesBefore,
    customAtMicros,
    enabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReminderRuleRow &&
          other.settlementId == this.settlementId &&
          other.ruleId == this.ruleId &&
          other.position == this.position &&
          other.type == this.type &&
          other.minutesBefore == this.minutesBefore &&
          other.customAtMicros == this.customAtMicros &&
          other.enabled == this.enabled);
}

class ZarReminderRulesCompanion extends UpdateCompanion<LocalReminderRuleRow> {
  final Value<String> settlementId;
  final Value<String> ruleId;
  final Value<int> position;
  final Value<String> type;
  final Value<int?> minutesBefore;
  final Value<int?> customAtMicros;
  final Value<bool> enabled;
  final Value<int> rowid;
  const ZarReminderRulesCompanion({
    this.settlementId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.position = const Value.absent(),
    this.type = const Value.absent(),
    this.minutesBefore = const Value.absent(),
    this.customAtMicros = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZarReminderRulesCompanion.insert({
    required String settlementId,
    required String ruleId,
    required int position,
    required String type,
    this.minutesBefore = const Value.absent(),
    this.customAtMicros = const Value.absent(),
    required bool enabled,
    this.rowid = const Value.absent(),
  }) : settlementId = Value(settlementId),
       ruleId = Value(ruleId),
       position = Value(position),
       type = Value(type),
       enabled = Value(enabled);
  static Insertable<LocalReminderRuleRow> custom({
    Expression<String>? settlementId,
    Expression<String>? ruleId,
    Expression<int>? position,
    Expression<String>? type,
    Expression<int>? minutesBefore,
    Expression<int>? customAtMicros,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (settlementId != null) 'settlement_id': settlementId,
      if (ruleId != null) 'rule_id': ruleId,
      if (position != null) 'position': position,
      if (type != null) 'type': type,
      if (minutesBefore != null) 'minutes_before': minutesBefore,
      if (customAtMicros != null) 'custom_at_micros': customAtMicros,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZarReminderRulesCompanion copyWith({
    Value<String>? settlementId,
    Value<String>? ruleId,
    Value<int>? position,
    Value<String>? type,
    Value<int?>? minutesBefore,
    Value<int?>? customAtMicros,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return ZarReminderRulesCompanion(
      settlementId: settlementId ?? this.settlementId,
      ruleId: ruleId ?? this.ruleId,
      position: position ?? this.position,
      type: type ?? this.type,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      customAtMicros: customAtMicros ?? this.customAtMicros,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (settlementId.present) {
      map['settlement_id'] = Variable<String>(settlementId.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (minutesBefore.present) {
      map['minutes_before'] = Variable<int>(minutesBefore.value);
    }
    if (customAtMicros.present) {
      map['custom_at_micros'] = Variable<int>(customAtMicros.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZarReminderRulesCompanion(')
          ..write('settlementId: $settlementId, ')
          ..write('ruleId: $ruleId, ')
          ..write('position: $position, ')
          ..write('type: $type, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('customAtMicros: $customAtMicros, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZarLocalMetadataTable extends ZarLocalMetadata
    with TableInfo<$ZarLocalMetadataTable, LocalMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZarLocalMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zar_local_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMetadataRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ZarLocalMetadataTable createAlias(String alias) {
    return $ZarLocalMetadataTable(attachedDatabase, alias);
  }
}

class LocalMetadataRow extends DataClass
    implements Insertable<LocalMetadataRow> {
  final String key;
  final String value;
  const LocalMetadataRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ZarLocalMetadataCompanion toCompanion(bool nullToAbsent) {
    return ZarLocalMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory LocalMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalMetadataRow copyWith({String? key, String? value}) =>
      LocalMetadataRow(key: key ?? this.key, value: value ?? this.value);
  LocalMetadataRow copyWithCompanion(ZarLocalMetadataCompanion data) {
    return LocalMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetadataRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMetadataRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ZarLocalMetadataCompanion extends UpdateCompanion<LocalMetadataRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ZarLocalMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZarLocalMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZarLocalMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ZarLocalMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZarLocalMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ZarLocalDatabase extends GeneratedDatabase {
  _$ZarLocalDatabase(QueryExecutor e) : super(e);
  $ZarLocalDatabaseManager get managers => $ZarLocalDatabaseManager(this);
  late final $ZarPeopleTable zarPeople = $ZarPeopleTable(this);
  late final $ZarDealsTable zarDeals = $ZarDealsTable(this);
  late final $ZarSettlementsTable zarSettlements = $ZarSettlementsTable(this);
  late final $ZarReminderRulesTable zarReminderRules = $ZarReminderRulesTable(
    this,
  );
  late final $ZarLocalMetadataTable zarLocalMetadata = $ZarLocalMetadataTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    zarPeople,
    zarDeals,
    zarSettlements,
    zarReminderRules,
    zarLocalMetadata,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'zar_settlements',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('zar_reminder_rules', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ZarPeopleTableCreateCompanionBuilder =
    ZarPeopleCompanion Function({
      required String id,
      required String displayName,
      Value<String?> phone,
      Value<String?> note,
      Value<bool> archived,
      required int createdAtMicros,
      required int updatedAtMicros,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$ZarPeopleTableUpdateCompanionBuilder =
    ZarPeopleCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String?> phone,
      Value<String?> note,
      Value<bool> archived,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<String> createdBy,
      Value<int> rowid,
    });

final class $$ZarPeopleTableReferences
    extends
        BaseReferences<_$ZarLocalDatabase, $ZarPeopleTable, LocalPersonRow> {
  $$ZarPeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ZarDealsTable, List<LocalDealRow>>
  _zarDealsRefsTable(_$ZarLocalDatabase db) => MultiTypedResultKey.fromTable(
    db.zarDeals,
    aliasName: 'zar_people__id__zar_deals__person_id',
  );

  $$ZarDealsTableProcessedTableManager get zarDealsRefs {
    final manager = $$ZarDealsTableTableManager(
      $_db,
      $_db.zarDeals,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_zarDealsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ZarSettlementsTable, List<LocalSettlementRow>>
  _zarSettlementsRefsTable(_$ZarLocalDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.zarSettlements,
        aliasName: 'zar_people__id__zar_settlements__person_id',
      );

  $$ZarSettlementsTableProcessedTableManager get zarSettlementsRefs {
    final manager = $$ZarSettlementsTableTableManager(
      $_db,
      $_db.zarSettlements,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_zarSettlementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ZarPeopleTableFilterComposer
    extends Composer<_$ZarLocalDatabase, $ZarPeopleTable> {
  $$ZarPeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> zarDealsRefs(
    Expression<bool> Function($$ZarDealsTableFilterComposer f) f,
  ) {
    final $$ZarDealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarDeals,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarDealsTableFilterComposer(
            $db: $db,
            $table: $db.zarDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> zarSettlementsRefs(
    Expression<bool> Function($$ZarSettlementsTableFilterComposer f) f,
  ) {
    final $$ZarSettlementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableFilterComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarPeopleTableOrderingComposer
    extends Composer<_$ZarLocalDatabase, $ZarPeopleTable> {
  $$ZarPeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZarPeopleTableAnnotationComposer
    extends Composer<_$ZarLocalDatabase, $ZarPeopleTable> {
  $$ZarPeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  Expression<T> zarDealsRefs<T extends Object>(
    Expression<T> Function($$ZarDealsTableAnnotationComposer a) f,
  ) {
    final $$ZarDealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarDeals,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarDealsTableAnnotationComposer(
            $db: $db,
            $table: $db.zarDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> zarSettlementsRefs<T extends Object>(
    Expression<T> Function($$ZarSettlementsTableAnnotationComposer a) f,
  ) {
    final $$ZarSettlementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableAnnotationComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarPeopleTableTableManager
    extends
        RootTableManager<
          _$ZarLocalDatabase,
          $ZarPeopleTable,
          LocalPersonRow,
          $$ZarPeopleTableFilterComposer,
          $$ZarPeopleTableOrderingComposer,
          $$ZarPeopleTableAnnotationComposer,
          $$ZarPeopleTableCreateCompanionBuilder,
          $$ZarPeopleTableUpdateCompanionBuilder,
          (LocalPersonRow, $$ZarPeopleTableReferences),
          LocalPersonRow,
          PrefetchHooks Function({bool zarDealsRefs, bool zarSettlementsRefs})
        > {
  $$ZarPeopleTableTableManager(_$ZarLocalDatabase db, $ZarPeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZarPeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZarPeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZarPeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZarPeopleCompanion(
                id: id,
                displayName: displayName,
                phone: phone,
                note: note,
                archived: archived,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                Value<String?> phone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => ZarPeopleCompanion.insert(
                id: id,
                displayName: displayName,
                phone: phone,
                note: note,
                archived: archived,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ZarPeopleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({zarDealsRefs = false, zarSettlementsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (zarDealsRefs) db.zarDeals,
                    if (zarSettlementsRefs) db.zarSettlements,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (zarDealsRefs)
                        await $_getPrefetchedData<
                          LocalPersonRow,
                          $ZarPeopleTable,
                          LocalDealRow
                        >(
                          currentTable: table,
                          referencedTable: $$ZarPeopleTableReferences
                              ._zarDealsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ZarPeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).zarDealsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (zarSettlementsRefs)
                        await $_getPrefetchedData<
                          LocalPersonRow,
                          $ZarPeopleTable,
                          LocalSettlementRow
                        >(
                          currentTable: table,
                          referencedTable: $$ZarPeopleTableReferences
                              ._zarSettlementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ZarPeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).zarSettlementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ZarPeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$ZarLocalDatabase,
      $ZarPeopleTable,
      LocalPersonRow,
      $$ZarPeopleTableFilterComposer,
      $$ZarPeopleTableOrderingComposer,
      $$ZarPeopleTableAnnotationComposer,
      $$ZarPeopleTableCreateCompanionBuilder,
      $$ZarPeopleTableUpdateCompanionBuilder,
      (LocalPersonRow, $$ZarPeopleTableReferences),
      LocalPersonRow,
      PrefetchHooks Function({bool zarDealsRefs, bool zarSettlementsRefs})
    >;
typedef $$ZarDealsTableCreateCompanionBuilder =
    ZarDealsCompanion Function({
      required String id,
      required String businessId,
      required String type,
      required String personId,
      required String assetType,
      Value<String?> goldDecimal,
      Value<String?> goldUnit,
      Value<String?> goldPurity,
      Value<String?> currencyCode,
      Value<int?> currencyMinorUnits,
      Value<int?> currencyMinorUnitScale,
      required int dealAtMicros,
      required String status,
      Value<String?> note,
      required String createdBy,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$ZarDealsTableUpdateCompanionBuilder =
    ZarDealsCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> type,
      Value<String> personId,
      Value<String> assetType,
      Value<String?> goldDecimal,
      Value<String?> goldUnit,
      Value<String?> goldPurity,
      Value<String?> currencyCode,
      Value<int?> currencyMinorUnits,
      Value<int?> currencyMinorUnitScale,
      Value<int> dealAtMicros,
      Value<String> status,
      Value<String?> note,
      Value<String> createdBy,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

final class $$ZarDealsTableReferences
    extends BaseReferences<_$ZarLocalDatabase, $ZarDealsTable, LocalDealRow> {
  $$ZarDealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ZarPeopleTable _personIdTable(_$ZarLocalDatabase db) =>
      db.zarPeople.createAlias('zar_deals__person_id__zar_people__id');

  $$ZarPeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$ZarPeopleTableTableManager(
      $_db,
      $_db.zarPeople,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ZarSettlementsTable, List<LocalSettlementRow>>
  _zarSettlementsRefsTable(_$ZarLocalDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.zarSettlements,
        aliasName: 'zar_deals__id__zar_settlements__deal_id',
      );

  $$ZarSettlementsTableProcessedTableManager get zarSettlementsRefs {
    final manager = $$ZarSettlementsTableTableManager(
      $_db,
      $_db.zarSettlements,
    ).filter((f) => f.dealId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_zarSettlementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ZarDealsTableFilterComposer
    extends Composer<_$ZarLocalDatabase, $ZarDealsTable> {
  $$ZarDealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldUnit => $composableBuilder(
    column: $table.goldUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dealAtMicros => $composableBuilder(
    column: $table.dealAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$ZarPeopleTableFilterComposer get personId {
    final $$ZarPeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableFilterComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> zarSettlementsRefs(
    Expression<bool> Function($$ZarSettlementsTableFilterComposer f) f,
  ) {
    final $$ZarSettlementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.dealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableFilterComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarDealsTableOrderingComposer
    extends Composer<_$ZarLocalDatabase, $ZarDealsTable> {
  $$ZarDealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldUnit => $composableBuilder(
    column: $table.goldUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dealAtMicros => $composableBuilder(
    column: $table.dealAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$ZarPeopleTableOrderingComposer get personId {
    final $$ZarPeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableOrderingComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ZarDealsTableAnnotationComposer
    extends Composer<_$ZarLocalDatabase, $ZarDealsTable> {
  $$ZarDealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get assetType =>
      $composableBuilder(column: $table.assetType, builder: (column) => column);

  GeneratedColumn<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goldUnit =>
      $composableBuilder(column: $table.goldUnit, builder: (column) => column);

  GeneratedColumn<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dealAtMicros => $composableBuilder(
    column: $table.dealAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  $$ZarPeopleTableAnnotationComposer get personId {
    final $$ZarPeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> zarSettlementsRefs<T extends Object>(
    Expression<T> Function($$ZarSettlementsTableAnnotationComposer a) f,
  ) {
    final $$ZarSettlementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.dealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableAnnotationComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarDealsTableTableManager
    extends
        RootTableManager<
          _$ZarLocalDatabase,
          $ZarDealsTable,
          LocalDealRow,
          $$ZarDealsTableFilterComposer,
          $$ZarDealsTableOrderingComposer,
          $$ZarDealsTableAnnotationComposer,
          $$ZarDealsTableCreateCompanionBuilder,
          $$ZarDealsTableUpdateCompanionBuilder,
          (LocalDealRow, $$ZarDealsTableReferences),
          LocalDealRow,
          PrefetchHooks Function({bool personId, bool zarSettlementsRefs})
        > {
  $$ZarDealsTableTableManager(_$ZarLocalDatabase db, $ZarDealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZarDealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZarDealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZarDealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> assetType = const Value.absent(),
                Value<String?> goldDecimal = const Value.absent(),
                Value<String?> goldUnit = const Value.absent(),
                Value<String?> goldPurity = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> currencyMinorUnits = const Value.absent(),
                Value<int?> currencyMinorUnitScale = const Value.absent(),
                Value<int> dealAtMicros = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZarDealsCompanion(
                id: id,
                businessId: businessId,
                type: type,
                personId: personId,
                assetType: assetType,
                goldDecimal: goldDecimal,
                goldUnit: goldUnit,
                goldPurity: goldPurity,
                currencyCode: currencyCode,
                currencyMinorUnits: currencyMinorUnits,
                currencyMinorUnitScale: currencyMinorUnitScale,
                dealAtMicros: dealAtMicros,
                status: status,
                note: note,
                createdBy: createdBy,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String type,
                required String personId,
                required String assetType,
                Value<String?> goldDecimal = const Value.absent(),
                Value<String?> goldUnit = const Value.absent(),
                Value<String?> goldPurity = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> currencyMinorUnits = const Value.absent(),
                Value<int?> currencyMinorUnitScale = const Value.absent(),
                required int dealAtMicros,
                required String status,
                Value<String?> note = const Value.absent(),
                required String createdBy,
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => ZarDealsCompanion.insert(
                id: id,
                businessId: businessId,
                type: type,
                personId: personId,
                assetType: assetType,
                goldDecimal: goldDecimal,
                goldUnit: goldUnit,
                goldPurity: goldPurity,
                currencyCode: currencyCode,
                currencyMinorUnits: currencyMinorUnits,
                currencyMinorUnitScale: currencyMinorUnitScale,
                dealAtMicros: dealAtMicros,
                status: status,
                note: note,
                createdBy: createdBy,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ZarDealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({personId = false, zarSettlementsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (zarSettlementsRefs) db.zarSettlements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable: $$ZarDealsTableReferences
                                        ._personIdTable(db),
                                    referencedColumn: $$ZarDealsTableReferences
                                        ._personIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (zarSettlementsRefs)
                        await $_getPrefetchedData<
                          LocalDealRow,
                          $ZarDealsTable,
                          LocalSettlementRow
                        >(
                          currentTable: table,
                          referencedTable: $$ZarDealsTableReferences
                              ._zarSettlementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ZarDealsTableReferences(
                                db,
                                table,
                                p0,
                              ).zarSettlementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.dealId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ZarDealsTableProcessedTableManager =
    ProcessedTableManager<
      _$ZarLocalDatabase,
      $ZarDealsTable,
      LocalDealRow,
      $$ZarDealsTableFilterComposer,
      $$ZarDealsTableOrderingComposer,
      $$ZarDealsTableAnnotationComposer,
      $$ZarDealsTableCreateCompanionBuilder,
      $$ZarDealsTableUpdateCompanionBuilder,
      (LocalDealRow, $$ZarDealsTableReferences),
      LocalDealRow,
      PrefetchHooks Function({bool personId, bool zarSettlementsRefs})
    >;
typedef $$ZarSettlementsTableCreateCompanionBuilder =
    ZarSettlementsCompanion Function({
      required String id,
      required String businessId,
      Value<String?> dealId,
      required String personId,
      required String direction,
      required String assetType,
      Value<String?> goldDecimal,
      Value<String?> goldUnit,
      Value<String?> goldPurity,
      Value<String?> currencyCode,
      Value<int?> currencyMinorUnits,
      Value<int?> currencyMinorUnitScale,
      required int scheduledAtMicros,
      required bool hasTime,
      required String status,
      Value<int?> snoozedUntilMicros,
      Value<int?> completedAtMicros,
      Value<String?> completedBy,
      Value<String?> note,
      required String createdBy,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$ZarSettlementsTableUpdateCompanionBuilder =
    ZarSettlementsCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String?> dealId,
      Value<String> personId,
      Value<String> direction,
      Value<String> assetType,
      Value<String?> goldDecimal,
      Value<String?> goldUnit,
      Value<String?> goldPurity,
      Value<String?> currencyCode,
      Value<int?> currencyMinorUnits,
      Value<int?> currencyMinorUnitScale,
      Value<int> scheduledAtMicros,
      Value<bool> hasTime,
      Value<String> status,
      Value<int?> snoozedUntilMicros,
      Value<int?> completedAtMicros,
      Value<String?> completedBy,
      Value<String?> note,
      Value<String> createdBy,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

final class $$ZarSettlementsTableReferences
    extends
        BaseReferences<
          _$ZarLocalDatabase,
          $ZarSettlementsTable,
          LocalSettlementRow
        > {
  $$ZarSettlementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ZarDealsTable _dealIdTable(_$ZarLocalDatabase db) =>
      db.zarDeals.createAlias('zar_settlements__deal_id__zar_deals__id');

  $$ZarDealsTableProcessedTableManager? get dealId {
    final $_column = $_itemColumn<String>('deal_id');
    if ($_column == null) return null;
    final manager = $$ZarDealsTableTableManager(
      $_db,
      $_db.zarDeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ZarPeopleTable _personIdTable(_$ZarLocalDatabase db) =>
      db.zarPeople.createAlias('zar_settlements__person_id__zar_people__id');

  $$ZarPeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$ZarPeopleTableTableManager(
      $_db,
      $_db.zarPeople,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ZarReminderRulesTable, List<LocalReminderRuleRow>>
  _zarReminderRulesRefsTable(_$ZarLocalDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.zarReminderRules,
        aliasName: 'zar_settlements__id__zar_reminder_rules__settlement_id',
      );

  $$ZarReminderRulesTableProcessedTableManager get zarReminderRulesRefs {
    final manager = $$ZarReminderRulesTableTableManager(
      $_db,
      $_db.zarReminderRules,
    ).filter((f) => f.settlementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _zarReminderRulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ZarSettlementsTableFilterComposer
    extends Composer<_$ZarLocalDatabase, $ZarSettlementsTable> {
  $$ZarSettlementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldUnit => $composableBuilder(
    column: $table.goldUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAtMicros => $composableBuilder(
    column: $table.scheduledAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasTime => $composableBuilder(
    column: $table.hasTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntilMicros => $composableBuilder(
    column: $table.snoozedUntilMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$ZarDealsTableFilterComposer get dealId {
    final $$ZarDealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.zarDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarDealsTableFilterComposer(
            $db: $db,
            $table: $db.zarDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZarPeopleTableFilterComposer get personId {
    final $$ZarPeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableFilterComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> zarReminderRulesRefs(
    Expression<bool> Function($$ZarReminderRulesTableFilterComposer f) f,
  ) {
    final $$ZarReminderRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarReminderRules,
      getReferencedColumn: (t) => t.settlementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarReminderRulesTableFilterComposer(
            $db: $db,
            $table: $db.zarReminderRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarSettlementsTableOrderingComposer
    extends Composer<_$ZarLocalDatabase, $ZarSettlementsTable> {
  $$ZarSettlementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldUnit => $composableBuilder(
    column: $table.goldUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAtMicros => $composableBuilder(
    column: $table.scheduledAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasTime => $composableBuilder(
    column: $table.hasTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntilMicros => $composableBuilder(
    column: $table.snoozedUntilMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$ZarDealsTableOrderingComposer get dealId {
    final $$ZarDealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.zarDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarDealsTableOrderingComposer(
            $db: $db,
            $table: $db.zarDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZarPeopleTableOrderingComposer get personId {
    final $$ZarPeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableOrderingComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ZarSettlementsTableAnnotationComposer
    extends Composer<_$ZarLocalDatabase, $ZarSettlementsTable> {
  $$ZarSettlementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get assetType =>
      $composableBuilder(column: $table.assetType, builder: (column) => column);

  GeneratedColumn<String> get goldDecimal => $composableBuilder(
    column: $table.goldDecimal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goldUnit =>
      $composableBuilder(column: $table.goldUnit, builder: (column) => column);

  GeneratedColumn<String> get goldPurity => $composableBuilder(
    column: $table.goldPurity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currencyMinorUnits => $composableBuilder(
    column: $table.currencyMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currencyMinorUnitScale => $composableBuilder(
    column: $table.currencyMinorUnitScale,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledAtMicros => $composableBuilder(
    column: $table.scheduledAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasTime =>
      $composableBuilder(column: $table.hasTime, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get snoozedUntilMicros => $composableBuilder(
    column: $table.snoozedUntilMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  $$ZarDealsTableAnnotationComposer get dealId {
    final $$ZarDealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.zarDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarDealsTableAnnotationComposer(
            $db: $db,
            $table: $db.zarDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ZarPeopleTableAnnotationComposer get personId {
    final $$ZarPeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.zarPeople,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarPeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.zarPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> zarReminderRulesRefs<T extends Object>(
    Expression<T> Function($$ZarReminderRulesTableAnnotationComposer a) f,
  ) {
    final $$ZarReminderRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.zarReminderRules,
      getReferencedColumn: (t) => t.settlementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarReminderRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.zarReminderRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ZarSettlementsTableTableManager
    extends
        RootTableManager<
          _$ZarLocalDatabase,
          $ZarSettlementsTable,
          LocalSettlementRow,
          $$ZarSettlementsTableFilterComposer,
          $$ZarSettlementsTableOrderingComposer,
          $$ZarSettlementsTableAnnotationComposer,
          $$ZarSettlementsTableCreateCompanionBuilder,
          $$ZarSettlementsTableUpdateCompanionBuilder,
          (LocalSettlementRow, $$ZarSettlementsTableReferences),
          LocalSettlementRow,
          PrefetchHooks Function({
            bool dealId,
            bool personId,
            bool zarReminderRulesRefs,
          })
        > {
  $$ZarSettlementsTableTableManager(
    _$ZarLocalDatabase db,
    $ZarSettlementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZarSettlementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZarSettlementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZarSettlementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String?> dealId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> assetType = const Value.absent(),
                Value<String?> goldDecimal = const Value.absent(),
                Value<String?> goldUnit = const Value.absent(),
                Value<String?> goldPurity = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> currencyMinorUnits = const Value.absent(),
                Value<int?> currencyMinorUnitScale = const Value.absent(),
                Value<int> scheduledAtMicros = const Value.absent(),
                Value<bool> hasTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> snoozedUntilMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZarSettlementsCompanion(
                id: id,
                businessId: businessId,
                dealId: dealId,
                personId: personId,
                direction: direction,
                assetType: assetType,
                goldDecimal: goldDecimal,
                goldUnit: goldUnit,
                goldPurity: goldPurity,
                currencyCode: currencyCode,
                currencyMinorUnits: currencyMinorUnits,
                currencyMinorUnitScale: currencyMinorUnitScale,
                scheduledAtMicros: scheduledAtMicros,
                hasTime: hasTime,
                status: status,
                snoozedUntilMicros: snoozedUntilMicros,
                completedAtMicros: completedAtMicros,
                completedBy: completedBy,
                note: note,
                createdBy: createdBy,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                Value<String?> dealId = const Value.absent(),
                required String personId,
                required String direction,
                required String assetType,
                Value<String?> goldDecimal = const Value.absent(),
                Value<String?> goldUnit = const Value.absent(),
                Value<String?> goldPurity = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> currencyMinorUnits = const Value.absent(),
                Value<int?> currencyMinorUnitScale = const Value.absent(),
                required int scheduledAtMicros,
                required bool hasTime,
                required String status,
                Value<int?> snoozedUntilMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String createdBy,
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => ZarSettlementsCompanion.insert(
                id: id,
                businessId: businessId,
                dealId: dealId,
                personId: personId,
                direction: direction,
                assetType: assetType,
                goldDecimal: goldDecimal,
                goldUnit: goldUnit,
                goldPurity: goldPurity,
                currencyCode: currencyCode,
                currencyMinorUnits: currencyMinorUnits,
                currencyMinorUnitScale: currencyMinorUnitScale,
                scheduledAtMicros: scheduledAtMicros,
                hasTime: hasTime,
                status: status,
                snoozedUntilMicros: snoozedUntilMicros,
                completedAtMicros: completedAtMicros,
                completedBy: completedBy,
                note: note,
                createdBy: createdBy,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ZarSettlementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                dealId = false,
                personId = false,
                zarReminderRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (zarReminderRulesRefs) db.zarReminderRules,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (dealId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.dealId,
                                    referencedTable:
                                        $$ZarSettlementsTableReferences
                                            ._dealIdTable(db),
                                    referencedColumn:
                                        $$ZarSettlementsTableReferences
                                            ._dealIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable:
                                        $$ZarSettlementsTableReferences
                                            ._personIdTable(db),
                                    referencedColumn:
                                        $$ZarSettlementsTableReferences
                                            ._personIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (zarReminderRulesRefs)
                        await $_getPrefetchedData<
                          LocalSettlementRow,
                          $ZarSettlementsTable,
                          LocalReminderRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$ZarSettlementsTableReferences
                              ._zarReminderRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ZarSettlementsTableReferences(
                                db,
                                table,
                                p0,
                              ).zarReminderRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.settlementId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ZarSettlementsTableProcessedTableManager =
    ProcessedTableManager<
      _$ZarLocalDatabase,
      $ZarSettlementsTable,
      LocalSettlementRow,
      $$ZarSettlementsTableFilterComposer,
      $$ZarSettlementsTableOrderingComposer,
      $$ZarSettlementsTableAnnotationComposer,
      $$ZarSettlementsTableCreateCompanionBuilder,
      $$ZarSettlementsTableUpdateCompanionBuilder,
      (LocalSettlementRow, $$ZarSettlementsTableReferences),
      LocalSettlementRow,
      PrefetchHooks Function({
        bool dealId,
        bool personId,
        bool zarReminderRulesRefs,
      })
    >;
typedef $$ZarReminderRulesTableCreateCompanionBuilder =
    ZarReminderRulesCompanion Function({
      required String settlementId,
      required String ruleId,
      required int position,
      required String type,
      Value<int?> minutesBefore,
      Value<int?> customAtMicros,
      required bool enabled,
      Value<int> rowid,
    });
typedef $$ZarReminderRulesTableUpdateCompanionBuilder =
    ZarReminderRulesCompanion Function({
      Value<String> settlementId,
      Value<String> ruleId,
      Value<int> position,
      Value<String> type,
      Value<int?> minutesBefore,
      Value<int?> customAtMicros,
      Value<bool> enabled,
      Value<int> rowid,
    });

final class $$ZarReminderRulesTableReferences
    extends
        BaseReferences<
          _$ZarLocalDatabase,
          $ZarReminderRulesTable,
          LocalReminderRuleRow
        > {
  $$ZarReminderRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ZarSettlementsTable _settlementIdTable(_$ZarLocalDatabase db) => db
      .zarSettlements
      .createAlias('zar_reminder_rules__settlement_id__zar_settlements__id');

  $$ZarSettlementsTableProcessedTableManager get settlementId {
    final $_column = $_itemColumn<String>('settlement_id')!;

    final manager = $$ZarSettlementsTableTableManager(
      $_db,
      $_db.zarSettlements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_settlementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ZarReminderRulesTableFilterComposer
    extends Composer<_$ZarLocalDatabase, $ZarReminderRulesTable> {
  $$ZarReminderRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customAtMicros => $composableBuilder(
    column: $table.customAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  $$ZarSettlementsTableFilterComposer get settlementId {
    final $$ZarSettlementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.settlementId,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableFilterComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ZarReminderRulesTableOrderingComposer
    extends Composer<_$ZarLocalDatabase, $ZarReminderRulesTable> {
  $$ZarReminderRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customAtMicros => $composableBuilder(
    column: $table.customAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$ZarSettlementsTableOrderingComposer get settlementId {
    final $$ZarSettlementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.settlementId,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableOrderingComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ZarReminderRulesTableAnnotationComposer
    extends Composer<_$ZarLocalDatabase, $ZarReminderRulesTable> {
  $$ZarReminderRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customAtMicros => $composableBuilder(
    column: $table.customAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  $$ZarSettlementsTableAnnotationComposer get settlementId {
    final $$ZarSettlementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.settlementId,
      referencedTable: $db.zarSettlements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ZarSettlementsTableAnnotationComposer(
            $db: $db,
            $table: $db.zarSettlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ZarReminderRulesTableTableManager
    extends
        RootTableManager<
          _$ZarLocalDatabase,
          $ZarReminderRulesTable,
          LocalReminderRuleRow,
          $$ZarReminderRulesTableFilterComposer,
          $$ZarReminderRulesTableOrderingComposer,
          $$ZarReminderRulesTableAnnotationComposer,
          $$ZarReminderRulesTableCreateCompanionBuilder,
          $$ZarReminderRulesTableUpdateCompanionBuilder,
          (LocalReminderRuleRow, $$ZarReminderRulesTableReferences),
          LocalReminderRuleRow,
          PrefetchHooks Function({bool settlementId})
        > {
  $$ZarReminderRulesTableTableManager(
    _$ZarLocalDatabase db,
    $ZarReminderRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZarReminderRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZarReminderRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZarReminderRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> settlementId = const Value.absent(),
                Value<String> ruleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> minutesBefore = const Value.absent(),
                Value<int?> customAtMicros = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZarReminderRulesCompanion(
                settlementId: settlementId,
                ruleId: ruleId,
                position: position,
                type: type,
                minutesBefore: minutesBefore,
                customAtMicros: customAtMicros,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String settlementId,
                required String ruleId,
                required int position,
                required String type,
                Value<int?> minutesBefore = const Value.absent(),
                Value<int?> customAtMicros = const Value.absent(),
                required bool enabled,
                Value<int> rowid = const Value.absent(),
              }) => ZarReminderRulesCompanion.insert(
                settlementId: settlementId,
                ruleId: ruleId,
                position: position,
                type: type,
                minutesBefore: minutesBefore,
                customAtMicros: customAtMicros,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ZarReminderRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({settlementId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (settlementId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.settlementId,
                                referencedTable:
                                    $$ZarReminderRulesTableReferences
                                        ._settlementIdTable(db),
                                referencedColumn:
                                    $$ZarReminderRulesTableReferences
                                        ._settlementIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ZarReminderRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$ZarLocalDatabase,
      $ZarReminderRulesTable,
      LocalReminderRuleRow,
      $$ZarReminderRulesTableFilterComposer,
      $$ZarReminderRulesTableOrderingComposer,
      $$ZarReminderRulesTableAnnotationComposer,
      $$ZarReminderRulesTableCreateCompanionBuilder,
      $$ZarReminderRulesTableUpdateCompanionBuilder,
      (LocalReminderRuleRow, $$ZarReminderRulesTableReferences),
      LocalReminderRuleRow,
      PrefetchHooks Function({bool settlementId})
    >;
typedef $$ZarLocalMetadataTableCreateCompanionBuilder =
    ZarLocalMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ZarLocalMetadataTableUpdateCompanionBuilder =
    ZarLocalMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$ZarLocalMetadataTableFilterComposer
    extends Composer<_$ZarLocalDatabase, $ZarLocalMetadataTable> {
  $$ZarLocalMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZarLocalMetadataTableOrderingComposer
    extends Composer<_$ZarLocalDatabase, $ZarLocalMetadataTable> {
  $$ZarLocalMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZarLocalMetadataTableAnnotationComposer
    extends Composer<_$ZarLocalDatabase, $ZarLocalMetadataTable> {
  $$ZarLocalMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ZarLocalMetadataTableTableManager
    extends
        RootTableManager<
          _$ZarLocalDatabase,
          $ZarLocalMetadataTable,
          LocalMetadataRow,
          $$ZarLocalMetadataTableFilterComposer,
          $$ZarLocalMetadataTableOrderingComposer,
          $$ZarLocalMetadataTableAnnotationComposer,
          $$ZarLocalMetadataTableCreateCompanionBuilder,
          $$ZarLocalMetadataTableUpdateCompanionBuilder,
          (
            LocalMetadataRow,
            BaseReferences<
              _$ZarLocalDatabase,
              $ZarLocalMetadataTable,
              LocalMetadataRow
            >,
          ),
          LocalMetadataRow,
          PrefetchHooks Function()
        > {
  $$ZarLocalMetadataTableTableManager(
    _$ZarLocalDatabase db,
    $ZarLocalMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZarLocalMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZarLocalMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZarLocalMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZarLocalMetadataCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ZarLocalMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZarLocalMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$ZarLocalDatabase,
      $ZarLocalMetadataTable,
      LocalMetadataRow,
      $$ZarLocalMetadataTableFilterComposer,
      $$ZarLocalMetadataTableOrderingComposer,
      $$ZarLocalMetadataTableAnnotationComposer,
      $$ZarLocalMetadataTableCreateCompanionBuilder,
      $$ZarLocalMetadataTableUpdateCompanionBuilder,
      (
        LocalMetadataRow,
        BaseReferences<
          _$ZarLocalDatabase,
          $ZarLocalMetadataTable,
          LocalMetadataRow
        >,
      ),
      LocalMetadataRow,
      PrefetchHooks Function()
    >;

class $ZarLocalDatabaseManager {
  final _$ZarLocalDatabase _db;
  $ZarLocalDatabaseManager(this._db);
  $$ZarPeopleTableTableManager get zarPeople =>
      $$ZarPeopleTableTableManager(_db, _db.zarPeople);
  $$ZarDealsTableTableManager get zarDeals =>
      $$ZarDealsTableTableManager(_db, _db.zarDeals);
  $$ZarSettlementsTableTableManager get zarSettlements =>
      $$ZarSettlementsTableTableManager(_db, _db.zarSettlements);
  $$ZarReminderRulesTableTableManager get zarReminderRules =>
      $$ZarReminderRulesTableTableManager(_db, _db.zarReminderRules);
  $$ZarLocalMetadataTableTableManager get zarLocalMetadata =>
      $$ZarLocalMetadataTableTableManager(_db, _db.zarLocalMetadata);
}
