import 'zar_reminder_plan.dart';

enum ZarAssetType { gold, currency, coin }

enum ZarDealType { buy, sell }

enum ZarDealStatus { active, completed, cancelled }

enum ZarSettlementDirection { receive, deliver }

enum ZarSettlementStatus { open, completed, cancelled }

enum ZarGoldUnit { gram, mesghal, coin, item }

enum ZarCoinCategory { official, parsian, other }

enum ZarCoinPricingMethod { perPiece, perGram }

const String zarGramsPerMesghal = '4.6083';

/// Exact decimal arithmetic used by Iranian gold-market calculations.
/// Values are represented as normalized decimal strings and all operations use
/// integers internally; binary floating point is never involved.
class ZarExactDecimal {
  ZarExactDecimal._(this.unscaled, this.scale);

  factory ZarExactDecimal.parse(String value) {
    final normalized = normalizeDecimal(value);
    final parts = normalized.split('.');
    final scale = parts.length == 2 ? parts[1].length : 0;
    return ZarExactDecimal._(BigInt.parse(parts.join()), scale);
  }

  final BigInt unscaled;
  final int scale;

  ZarExactDecimal multiply(ZarExactDecimal other) => ZarExactDecimal._(
    unscaled * other.unscaled,
    scale + other.scale,
  )._trimmed();

  ZarExactDecimal add(ZarExactDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    final left = unscaled * _pow10(targetScale - scale);
    final right = other.unscaled * _pow10(targetScale - other.scale);
    return ZarExactDecimal._(left + right, targetScale)._trimmed();
  }

  ZarExactDecimal divide(ZarExactDecimal other, {int decimalPlaces = 8}) {
    if (other.unscaled == BigInt.zero) {
      throw const FormatException('Cannot divide by zero.');
    }
    final numerator = unscaled * _pow10(other.scale + decimalPlaces);
    final denominator = other.unscaled * _pow10(scale);
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    final rounded = remainder.abs() * BigInt.two >= denominator.abs()
        ? quotient + BigInt.one
        : quotient;
    return ZarExactDecimal._(rounded, decimalPlaces)._trimmed();
  }

  int roundToWhole() {
    if (scale == 0) return unscaled.toInt();
    final divisor = _pow10(scale);
    final quotient = unscaled ~/ divisor;
    final remainder = unscaled.remainder(divisor);
    return (remainder * BigInt.two >= divisor
            ? quotient + BigInt.one
            : quotient)
        .toInt();
  }

  ZarExactDecimal _trimmed() {
    var value = unscaled;
    var digits = scale;
    while (digits > 0 && value.remainder(BigInt.from(10)) == BigInt.zero) {
      value ~/= BigInt.from(10);
      digits--;
    }
    return ZarExactDecimal._(value, digits);
  }

  @override
  String toString() {
    if (scale == 0) return unscaled.toString();
    final digits = unscaled.abs().toString().padLeft(scale + 1, '0');
    final split = digits.length - scale;
    final sign = unscaled.isNegative ? '-' : '';
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }

  static BigInt _pow10(int exponent) => BigInt.from(10).pow(exponent);
}

String zarGoldWeightInGrams(String value, ZarGoldUnit unit) {
  final input = ZarExactDecimal.parse(value);
  return switch (unit) {
    ZarGoldUnit.gram => input.toString(),
    ZarGoldUnit.mesghal =>
      input.multiply(ZarExactDecimal.parse(zarGramsPerMesghal)).toString(),
    _ => throw const FormatException(
      'Gold deals support gram or mesghal only.',
    ),
  };
}

String zarGoldWeightInMesghal(String grams, {int decimalPlaces = 8}) =>
    ZarExactDecimal.parse(grams)
        .divide(
          ZarExactDecimal.parse(zarGramsPerMesghal),
          decimalPlaces: decimalPlaces,
        )
        .toString();

class ZarTomanAmount {
  const ZarTomanAmount._(this.wholeTomans);

  static const maxExactValue = 9007199254740991;

  factory ZarTomanAmount(int wholeTomans) {
    if (wholeTomans <= 0) {
      throw const FormatException('Toman amount must be greater than zero.');
    }
    if (wholeTomans > maxExactValue) {
      throw const FormatException('Toman amount exceeds the exact range.');
    }
    return ZarTomanAmount._(wholeTomans);
  }

  final int wholeTomans;

  Map<String, Object?> toMap() => {'wholeTomans': wholeTomans};

  factory ZarTomanAmount.fromMap(Map<String, Object?> map) =>
      ZarTomanAmount(map['wholeTomans']! as int);
}

sealed class ZarDealPricing {
  const ZarDealPricing();

  ZarTomanAmount get totalToman;
  Map<String, Object?> toMap();

  static ZarDealPricing fromMap(Map<String, Object?> map) {
    switch (map['kind']) {
      case 'gold':
        return ZarGoldDealPricing.fromMap(map);
      case 'currency':
        return ZarCurrencyDealPricing.fromMap(map);
      case 'coin':
        return ZarCoinDealPricing.fromMap(map);
      default:
        throw const FormatException('Unsupported deal pricing kind.');
    }
  }
}

class ZarGoldDealPricing extends ZarDealPricing {
  ZarGoldDealPricing({
    required Object fineness,
    Object? priceReferenceFineness,
    String inputWeight = '1',
    this.inputWeightUnit = ZarGoldUnit.gram,
    this.priceUnit = ZarGoldUnit.gram,
    ZarTomanAmount? pricePerUnitToman,
    ZarTomanAmount? pricePerGramToman,
    required this.totalToman,
  }) : fineness = normalizeGoldFineness(fineness.toString()),
       priceReferenceFineness = normalizeGoldFineness(
         (priceReferenceFineness ?? fineness).toString(),
       ),
       inputWeight = normalizeDecimal(inputWeight),
       pricePerUnitToman =
           pricePerUnitToman ??
           pricePerGramToman ??
           (throw const FormatException('Gold unit price is required.')) {
    if (!const {
          ZarGoldUnit.gram,
          ZarGoldUnit.mesghal,
        }.contains(inputWeightUnit) ||
        !const {ZarGoldUnit.gram, ZarGoldUnit.mesghal}.contains(priceUnit)) {
      throw const FormatException(
        'Gold pricing supports gram or mesghal only.',
      );
    }
  }

  factory ZarGoldDealPricing.calculate({
    required Object fineness,
    Object? priceReferenceFineness,
    required String inputWeight,
    required ZarGoldUnit inputWeightUnit,
    required ZarGoldUnit priceUnit,
    required ZarTomanAmount pricePerUnitToman,
  }) {
    final input = ZarExactDecimal.parse(inputWeight);
    final price = ZarExactDecimal.parse(
      pricePerUnitToman.wholeTomans.toString(),
    );
    final converted = switch ((inputWeightUnit, priceUnit)) {
      (ZarGoldUnit.gram, ZarGoldUnit.gram) ||
      (ZarGoldUnit.mesghal, ZarGoldUnit.mesghal) => input,
      (ZarGoldUnit.mesghal, ZarGoldUnit.gram) => input.multiply(
        ZarExactDecimal.parse(zarGramsPerMesghal),
      ),
      (ZarGoldUnit.gram, ZarGoldUnit.mesghal) => input.divide(
        ZarExactDecimal.parse(zarGramsPerMesghal),
      ),
      _ => throw const FormatException(
        'Gold pricing supports gram or mesghal only.',
      ),
    };
    final actual = ZarExactDecimal.parse(fineness.toString());
    final reference = ZarExactDecimal.parse(
      (priceReferenceFineness ?? fineness).toString(),
    );
    final equivalent = converted
        .multiply(actual)
        .divide(reference, decimalPlaces: 12);
    final total = equivalent.multiply(price).roundToWhole();
    return ZarGoldDealPricing(
      fineness: fineness,
      priceReferenceFineness: priceReferenceFineness ?? fineness,
      inputWeight: inputWeight,
      inputWeightUnit: inputWeightUnit,
      priceUnit: priceUnit,
      pricePerUnitToman: pricePerUnitToman,
      totalToman: ZarTomanAmount(total),
    );
  }

  final String fineness;
  final String priceReferenceFineness;
  final String inputWeight;
  final ZarGoldUnit inputWeightUnit;
  final ZarGoldUnit priceUnit;
  final ZarTomanAmount pricePerUnitToman;
  String get normalizedWeightGrams =>
      zarGoldWeightInGrams(inputWeight, inputWeightUnit);
  String get equivalentWeightMesghal =>
      zarGoldWeightInMesghal(normalizedWeightGrams);
  String get equivalentQuantityInPriceUnit {
    final input = ZarExactDecimal.parse(inputWeight);
    final converted = switch ((inputWeightUnit, priceUnit)) {
      (ZarGoldUnit.gram, ZarGoldUnit.gram) ||
      (ZarGoldUnit.mesghal, ZarGoldUnit.mesghal) => input,
      (ZarGoldUnit.mesghal, ZarGoldUnit.gram) => input.multiply(
        ZarExactDecimal.parse(zarGramsPerMesghal),
      ),
      (ZarGoldUnit.gram, ZarGoldUnit.mesghal) => input.divide(
        ZarExactDecimal.parse(zarGramsPerMesghal),
      ),
      _ => throw const FormatException('Unsupported gold unit.'),
    };
    return converted
        .multiply(ZarExactDecimal.parse(fineness))
        .divide(ZarExactDecimal.parse(priceReferenceFineness), decimalPlaces: 8)
        .toString();
  }

  /// Backwards-compatible Phase 1 accessor for records priced per gram.
  ZarTomanAmount get pricePerGramToman {
    if (priceUnit != ZarGoldUnit.gram) {
      throw StateError('This gold deal is priced per mesghal.');
    }
    return pricePerUnitToman;
  }

  String get equivalentPricePerGramToman => priceUnit == ZarGoldUnit.gram
      ? pricePerUnitToman.wholeTomans.toString()
      : ZarExactDecimal.parse(
          pricePerUnitToman.wholeTomans.toString(),
        ).divide(ZarExactDecimal.parse(zarGramsPerMesghal)).toString();
  String get equivalentPricePerMesghalToman => priceUnit == ZarGoldUnit.mesghal
      ? pricePerUnitToman.wholeTomans.toString()
      : ZarExactDecimal.parse(
          pricePerUnitToman.wholeTomans.toString(),
        ).multiply(ZarExactDecimal.parse(zarGramsPerMesghal)).toString();
  @override
  final ZarTomanAmount totalToman;

  @override
  Map<String, Object?> toMap() => {
    'kind': 'gold',
    'fineness': fineness,
    'priceReferenceFineness': priceReferenceFineness,
    'inputWeight': inputWeight,
    'inputWeightUnit': inputWeightUnit.name,
    'priceUnit': priceUnit.name,
    'pricePerUnitToman': pricePerUnitToman.toMap(),
    'totalToman': totalToman.toMap(),
  };

  factory ZarGoldDealPricing.fromMap(Map<String, Object?> map) =>
      ZarGoldDealPricing(
        fineness: map['fineness']!,
        priceReferenceFineness:
            map['priceReferenceFineness'] ?? map['fineness']!,
        inputWeight: map['inputWeight']! as String,
        inputWeightUnit: ZarGoldUnit.values.byName(
          map['inputWeightUnit']! as String,
        ),
        priceUnit: ZarGoldUnit.values.byName(map['priceUnit']! as String),
        pricePerUnitToman: ZarTomanAmount.fromMap(
          Map<String, Object?>.from(map['pricePerUnitToman']! as Map),
        ),
        totalToman: ZarTomanAmount.fromMap(
          Map<String, Object?>.from(map['totalToman']! as Map),
        ),
      );
}

class ZarCurrencyDealPricing extends ZarDealPricing {
  ZarCurrencyDealPricing({
    required String tomanPerUnit,
    required this.totalToman,
  }) : tomanPerUnit = normalizeDecimal(tomanPerUnit);

  final String tomanPerUnit;
  @override
  final ZarTomanAmount totalToman;

  factory ZarCurrencyDealPricing.calculate({
    required String amount,
    required String tomanPerUnit,
  }) {
    final normalizedRate = normalizeDecimal(tomanPerUnit);
    final total = ZarExactDecimal.parse(
      amount,
    ).multiply(ZarExactDecimal.parse(normalizedRate)).roundToWhole();
    return ZarCurrencyDealPricing(
      tomanPerUnit: normalizedRate,
      totalToman: ZarTomanAmount(total),
    );
  }

  @override
  Map<String, Object?> toMap() => {
    'kind': 'currency',
    'tomanPerUnit': tomanPerUnit,
    'totalToman': totalToman.toMap(),
  };

  factory ZarCurrencyDealPricing.fromMap(Map<String, Object?> map) =>
      ZarCurrencyDealPricing(
        tomanPerUnit: map['tomanPerUnit']! as String,
        totalToman: ZarTomanAmount.fromMap(
          Map<String, Object?>.from(map['totalToman']! as Map),
        ),
      );
}

class ZarCoinType {
  ZarCoinType({
    required this.id,
    required String name,
    required this.category,
    String? defaultWeightGrams,
    String? defaultFineness,
    required this.defaultPricingMethod,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim(),
       defaultWeightGrams = defaultWeightGrams == null
           ? null
           : normalizeDecimal(defaultWeightGrams),
       defaultFineness = defaultFineness == null
           ? null
           : normalizeGoldFineness(defaultFineness) {
    if (id.trim().isEmpty || this.name.isEmpty) {
      throw const FormatException('Coin type id and name are required.');
    }
  }

  final String id;
  final String name;
  final ZarCoinCategory category;
  final String? defaultWeightGrams;
  final String? defaultFineness;
  final ZarCoinPricingMethod defaultPricingMethod;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  ZarCoinType copyWith({
    String? name,
    ZarCoinCategory? category,
    String? defaultWeightGrams,
    bool clearDefaultWeight = false,
    String? defaultFineness,
    bool clearDefaultFineness = false,
    ZarCoinPricingMethod? defaultPricingMethod,
    bool? archived,
    DateTime? updatedAt,
  }) => ZarCoinType(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    defaultWeightGrams: clearDefaultWeight
        ? null
        : defaultWeightGrams ?? this.defaultWeightGrams,
    defaultFineness: clearDefaultFineness
        ? null
        : defaultFineness ?? this.defaultFineness,
    defaultPricingMethod: defaultPricingMethod ?? this.defaultPricingMethod,
    archived: archived ?? this.archived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category.name,
    'defaultWeightGrams': defaultWeightGrams,
    'defaultFineness': defaultFineness,
    'defaultPricingMethod': defaultPricingMethod.name,
    'archived': archived,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ZarCoinType.fromMap(Map<String, Object?> map) => ZarCoinType(
    id: map['id']! as String,
    name: map['name']! as String,
    category: ZarCoinCategory.values.byName(map['category']! as String),
    defaultWeightGrams: map['defaultWeightGrams'] as String?,
    defaultFineness: map['defaultFineness'] as String?,
    defaultPricingMethod: ZarCoinPricingMethod.values.byName(
      map['defaultPricingMethod']! as String,
    ),
    archived: map['archived'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt']! as String),
    updatedAt: DateTime.parse(map['updatedAt']! as String),
  );
}

List<ZarCoinType> zarInitialCoinTypes({DateTime? now}) {
  final timestamp = (now ?? DateTime.now()).toUtc();
  return [
    ZarCoinType(
      id: 'coin-emami',
      name: 'سکه امامی',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-bahar-old',
      name: 'سکه تمام طرح قدیم',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-half',
      name: 'نیم‌سکه',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-quarter',
      name: 'ربع‌سکه',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-one-gram',
      name: 'سکه یک‌گرمی',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-parsian',
      name: 'سکه پارسیان',
      category: ZarCoinCategory.parsian,
      defaultFineness: '750',
      defaultPricingMethod: ZarCoinPricingMethod.perGram,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    ZarCoinType(
      id: 'coin-other',
      name: 'سایر سکه‌ها',
      category: ZarCoinCategory.other,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  ];
}

class ZarCoinLine {
  ZarCoinLine({
    required this.id,
    required this.coinTypeId,
    required String coinTypeNameSnapshot,
    required this.quantity,
    String? weightPerPieceGrams,
    String? fineness,
  }) : coinTypeNameSnapshot = coinTypeNameSnapshot.trim(),
       weightPerPieceGrams = weightPerPieceGrams == null
           ? null
           : normalizeDecimal(weightPerPieceGrams),
       fineness = fineness == null ? null : normalizeGoldFineness(fineness) {
    if (id.trim().isEmpty ||
        coinTypeId.trim().isEmpty ||
        this.coinTypeNameSnapshot.isEmpty ||
        quantity <= 0) {
      throw const FormatException('Invalid coin line.');
    }
  }
  final String id;
  final String coinTypeId;
  final String coinTypeNameSnapshot;
  final int quantity;
  final String? weightPerPieceGrams;
  final String? fineness;
  Map<String, Object?> toMap() => {
    'id': id,
    'coinTypeId': coinTypeId,
    'coinTypeNameSnapshot': coinTypeNameSnapshot,
    'quantity': quantity,
    'weightPerPieceGrams': weightPerPieceGrams,
    'fineness': fineness,
  };
  factory ZarCoinLine.fromMap(Map<String, Object?> map) => ZarCoinLine(
    id: map['id']! as String,
    coinTypeId: map['coinTypeId']! as String,
    coinTypeNameSnapshot: map['coinTypeNameSnapshot']! as String,
    quantity: map['quantity']! as int,
    weightPerPieceGrams: map['weightPerPieceGrams'] as String?,
    fineness: map['fineness'] as String?,
  );
}

class ZarCoinLinePricing {
  ZarCoinLinePricing({
    required this.lineId,
    required this.method,
    required this.unitPriceToman,
    String? priceReferenceFineness,
    required this.rowTotalToman,
  }) : priceReferenceFineness = priceReferenceFineness == null
           ? null
           : normalizeGoldFineness(priceReferenceFineness);
  factory ZarCoinLinePricing.calculate({
    required ZarCoinLine line,
    required ZarCoinPricingMethod method,
    required ZarTomanAmount unitPriceToman,
    String priceReferenceFineness = '750',
  }) {
    final quantity = ZarExactDecimal.parse(line.quantity.toString());
    var total = quantity.multiply(
      ZarExactDecimal.parse(unitPriceToman.wholeTomans.toString()),
    );
    String? reference;
    if (method == ZarCoinPricingMethod.perGram) {
      if (line.weightPerPieceGrams == null || line.fineness == null) {
        throw const FormatException(
          'Weighted coin pricing requires weight and fineness.',
        );
      }
      reference = normalizeGoldFineness(priceReferenceFineness);
      total = quantity
          .multiply(ZarExactDecimal.parse(line.weightPerPieceGrams!))
          .multiply(ZarExactDecimal.parse(line.fineness!))
          .divide(ZarExactDecimal.parse(reference), decimalPlaces: 12)
          .multiply(
            ZarExactDecimal.parse(unitPriceToman.wholeTomans.toString()),
          );
    }
    return ZarCoinLinePricing(
      lineId: line.id,
      method: method,
      unitPriceToman: unitPriceToman,
      priceReferenceFineness: reference,
      rowTotalToman: ZarTomanAmount(total.roundToWhole()),
    );
  }
  final String lineId;
  final ZarCoinPricingMethod method;
  final ZarTomanAmount unitPriceToman;
  final String? priceReferenceFineness;
  final ZarTomanAmount rowTotalToman;
  Map<String, Object?> toMap() => {
    'lineId': lineId,
    'method': method.name,
    'unitPriceToman': unitPriceToman.toMap(),
    'priceReferenceFineness': priceReferenceFineness,
    'rowTotalToman': rowTotalToman.toMap(),
  };
  factory ZarCoinLinePricing.fromMap(Map<String, Object?> map) =>
      ZarCoinLinePricing(
        lineId: map['lineId']! as String,
        method: ZarCoinPricingMethod.values.byName(map['method']! as String),
        unitPriceToman: ZarTomanAmount.fromMap(
          Map<String, Object?>.from(map['unitPriceToman']! as Map),
        ),
        priceReferenceFineness: map['priceReferenceFineness'] as String?,
        rowTotalToman: ZarTomanAmount.fromMap(
          Map<String, Object?>.from(map['rowTotalToman']! as Map),
        ),
      );
}

class ZarCoinDealPricing extends ZarDealPricing {
  ZarCoinDealPricing({required List<ZarCoinLinePricing> lines})
    : lines = List.unmodifiable(lines),
      totalToman = ZarTomanAmount(
        lines.fold<int>(0, (sum, line) => sum + line.rowTotalToman.wholeTomans),
      ) {
    if (lines.isEmpty) {
      throw const FormatException(
        'Coin deal pricing requires at least one line.',
      );
    }
  }
  final List<ZarCoinLinePricing> lines;
  @override
  final ZarTomanAmount totalToman;
  @override
  Map<String, Object?> toMap() => {
    'kind': 'coin',
    'lines': lines.map((e) => e.toMap()).toList(),
    'totalToman': totalToman.toMap(),
  };
  factory ZarCoinDealPricing.fromMap(Map<String, Object?> map) =>
      ZarCoinDealPricing(
        lines: (map['lines']! as List)
            .map(
              (e) => ZarCoinLinePricing.fromMap(
                Map<String, Object?>.from(e as Map),
              ),
            )
            .toList(),
      );
}

class ZarCoinSettlementValuation {
  ZarCoinSettlementValuation({required List<ZarCoinLinePricing> lines})
    : lines = List.unmodifiable(lines),
      totalToman = ZarTomanAmount(
        lines.fold<int>(0, (sum, line) => sum + line.rowTotalToman.wholeTomans),
      ) {
    if (lines.isEmpty) {
      throw const FormatException('Coin valuation requires at least one line.');
    }
  }
  final List<ZarCoinLinePricing> lines;
  final ZarTomanAmount totalToman;
  Map<String, Object?> toMap() => {
    'lines': lines.map((e) => e.toMap()).toList(),
    'totalToman': totalToman.toMap(),
  };
  factory ZarCoinSettlementValuation.fromMap(Map<String, Object?> map) =>
      ZarCoinSettlementValuation(
        lines: (map['lines']! as List)
            .map(
              (e) => ZarCoinLinePricing.fromMap(
                Map<String, Object?>.from(e as Map),
              ),
            )
            .toList(),
      );
}

/// Decimal-safe gold quantity. The canonical value is kept as a normalized
/// decimal string so business math never depends on binary floating point.
class ZarGoldQuantity {
  ZarGoldQuantity._(this.decimal, this.unit, this.purity);

  factory ZarGoldQuantity({
    required String decimal,
    ZarGoldUnit unit = ZarGoldUnit.gram,
    String? purity,
  }) {
    final normalized = normalizeDecimal(decimal);
    if (normalized == '0') {
      throw const FormatException('Gold quantity must be greater than zero.');
    }
    return ZarGoldQuantity._(
      normalized,
      unit,
      purity == null ? null : normalizeGoldQuantityPurity(purity),
    );
  }

  final String decimal;
  final ZarGoldUnit unit;
  final String? purity;

  Map<String, Object?> toMap() => {
    'decimal': decimal,
    'unit': unit.name,
    'purity': purity,
  };

  factory ZarGoldQuantity.fromMap(Map<String, Object?> map) => ZarGoldQuantity(
    decimal: map['decimal']! as String,
    unit: ZarGoldUnit.values.byName(map['unit']! as String),
    purity: map['purity'] as String?,
  );
}

/// Currency quantity stored in integer minor units. This keeps arithmetic exact
/// for standard fiat currencies and avoids storing display-formatted strings.
class ZarCurrencyAmount {
  const ZarCurrencyAmount._({
    required this.code,
    required this.minorUnits,
    required this.minorUnitScale,
  });

  factory ZarCurrencyAmount({
    required String code,
    required int minorUnits,
    int minorUnitScale = 2,
  }) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw const FormatException('Currency code is required.');
    }
    if (minorUnits <= 0) {
      throw const FormatException('Currency amount must be greater than zero.');
    }
    if (minorUnitScale < 0 || minorUnitScale > 6) {
      throw const FormatException('Unsupported currency minor-unit scale.');
    }
    return ZarCurrencyAmount._(
      code: normalizedCode,
      minorUnits: minorUnits,
      minorUnitScale: minorUnitScale,
    );
  }

  final String code;
  final int minorUnits;
  final int minorUnitScale;

  Map<String, Object?> toMap() => {
    'code': code,
    'minorUnits': minorUnits,
    'minorUnitScale': minorUnitScale,
  };

  factory ZarCurrencyAmount.fromMap(Map<String, Object?> map) =>
      ZarCurrencyAmount(
        code: map['code']! as String,
        minorUnits: map['minorUnits']! as int,
        minorUnitScale: map['minorUnitScale'] as int? ?? 2,
      );
}

sealed class ZarAssetAmount {
  const ZarAssetAmount();

  ZarAssetType get assetType;

  Map<String, Object?> toMap();

  static ZarAssetAmount fromMap(Map<String, Object?> map) {
    final type = ZarAssetType.values.byName(map['assetType']! as String);
    switch (type) {
      case ZarAssetType.gold:
        return ZarGoldAssetAmount(
          ZarGoldQuantity.fromMap(
            Map<String, Object?>.from(map['gold']! as Map),
          ),
        );
      case ZarAssetType.currency:
        return ZarCurrencyAssetAmount(
          ZarCurrencyAmount.fromMap(
            Map<String, Object?>.from(map['currency']! as Map),
          ),
        );
      case ZarAssetType.coin:
        return ZarCoinBundleAmount(
          (map['coinLines']! as List)
              .map(
                (item) =>
                    ZarCoinLine.fromMap(Map<String, Object?>.from(item as Map)),
              )
              .toList(),
        );
    }
  }
}

class ZarCoinBundleAmount extends ZarAssetAmount {
  ZarCoinBundleAmount(List<ZarCoinLine> lines)
    : lines = List.unmodifiable(lines) {
    if (lines.isEmpty || lines.map((e) => e.id).toSet().length != lines.length) {
      throw const FormatException(
        'Coin bundle requires unique non-empty lines.',
      );
    }
  }
  final List<ZarCoinLine> lines;
  @override
  ZarAssetType get assetType => ZarAssetType.coin;
  @override
  Map<String, Object?> toMap() => {
    'assetType': assetType.name,
    'coinLines': lines.map((e) => e.toMap()).toList(),
  };
}

class ZarGoldAssetAmount extends ZarAssetAmount {
  const ZarGoldAssetAmount(this.value);

  final ZarGoldQuantity value;

  @override
  ZarAssetType get assetType => ZarAssetType.gold;

  @override
  Map<String, Object?> toMap() => {
    'assetType': assetType.name,
    'gold': value.toMap(),
  };
}

class ZarCurrencyAssetAmount extends ZarAssetAmount {
  const ZarCurrencyAssetAmount(this.value);

  final ZarCurrencyAmount value;

  @override
  ZarAssetType get assetType => ZarAssetType.currency;

  @override
  Map<String, Object?> toMap() => {
    'assetType': assetType.name,
    'currency': value.toMap(),
  };
}

class ZarPerson {
  ZarPerson({
    required this.id,
    required this.displayName,
    String? phone,
    String? note,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  }) : phone = _trimOrNull(phone),
       note = _trimOrNull(note) {
    if (displayName.trim().isEmpty) {
      throw const FormatException('Person display name is required.');
    }
  }

  final String id;
  final String displayName;
  final String? phone;
  final String? note;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
}

class ZarDeal {
  ZarDeal({
    required this.id,
    required this.businessId,
    required this.type,
    required this.personId,
    required this.amount,
    this.pricing,
    required this.dealAt,
    this.status = ZarDealStatus.active,
    String? note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : note = _trimOrNull(note) {
    _validateTimestamp(dealAt, 'dealAt');
    final dealPricing = pricing;
    final dealAmount = amount;
    if (dealPricing is ZarGoldDealPricing &&
        dealAmount is! ZarGoldAssetAmount) {
      throw const FormatException('Gold pricing requires a gold deal amount.');
    }
    if (dealPricing is ZarGoldDealPricing &&
        dealAmount is ZarGoldAssetAmount &&
        dealAmount.value.purity != dealPricing.fineness.toString()) {
      throw const FormatException(
        'Gold amount purity must match deal pricing fineness.',
      );
    }
    if (dealPricing is ZarCurrencyDealPricing &&
        dealAmount is! ZarCurrencyAssetAmount) {
      throw const FormatException(
        'Currency pricing requires a currency deal amount.',
      );
    }
    if (dealAmount is ZarCoinBundleAmount) {
      if (dealPricing is! ZarCoinDealPricing) {
        throw const FormatException('Coin deals require typed coin pricing.');
      }
      final amountIds = dealAmount.lines.map((e) => e.id).toSet();
      final pricingIds = dealPricing.lines.map((e) => e.lineId).toSet();
      if (amountIds.length != pricingIds.length ||
          !amountIds.containsAll(pricingIds)) {
        throw const FormatException(
          'Coin deal pricing must cover every coin line exactly once.',
        );
      }
    } else if (dealPricing is ZarCoinDealPricing) {
      throw const FormatException('Coin pricing requires a coin bundle.');
    }
  }

  final String id;
  final String businessId;
  final ZarDealType type;
  final String personId;
  final ZarAssetAmount amount;
  final ZarDealPricing? pricing;
  final DateTime dealAt;
  final ZarDealStatus status;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ZarSettlement {
  ZarSettlement({
    required this.id,
    required this.businessId,
    String? dealId,
    required this.personId,
    required this.direction,
    required this.amount,
    required this.scheduledAt,
    required this.hasTime,
    this.status = ZarSettlementStatus.open,
    this.reminderPlan = const ZarReminderPlan(),
    this.coinValuation,
    this.completedAt,
    String? completedBy,
    String? note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : dealId = _trimOrNull(dealId),
       completedBy = _trimOrNull(completedBy),
       note = _trimOrNull(note) {
    _validateTimestamp(scheduledAt, 'scheduledAt');
    if (status == ZarSettlementStatus.completed && completedAt == null) {
      throw const FormatException('Completed settlement requires completedAt.');
    }
    if (status != ZarSettlementStatus.completed && completedAt != null) {
      throw const FormatException(
        'Only completed settlements may have completedAt.',
      );
    }
    if (coinValuation != null) {
      if (amount is! ZarCoinBundleAmount) {
        throw const FormatException(
          'Coin valuation requires a coin settlement.',
        );
      }
      final amountIds = (amount as ZarCoinBundleAmount).lines
          .map((e) => e.id)
          .toSet();
      final pricingIds = coinValuation!.lines.map((e) => e.lineId).toSet();
      if (!amountIds.containsAll(pricingIds) ||
          pricingIds.length != coinValuation!.lines.length) {
        throw const FormatException(
          'Coin settlement valuation references an unknown line.',
        );
      }
    }
  }

  final String id;
  final String businessId;
  final String? dealId;
  final String personId;
  final ZarSettlementDirection direction;
  final ZarAssetAmount amount;
  final DateTime scheduledAt;
  final bool hasTime;
  final ZarSettlementStatus status;
  final ZarReminderPlan reminderPlan;
  final ZarCoinSettlementValuation? coinValuation;
  final DateTime? completedAt;
  final String? completedBy;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == ZarSettlementStatus.open;
}

String normalizeDecimal(String input) {
  final value = _latinDigits(input.trim())
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll(' ', '')
      .replaceAll('٫', '.');

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Invalid decimal value.');
  }

  final parts = value.split('.');
  final integer = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (parts.length == 1) return integer;
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? integer : '$integer.$fraction';
}

String normalizeGoldFineness(String input) {
  final normalized = normalizeDecimal(input);
  final value = ZarExactDecimal.parse(normalized);
  if (value.unscaled == BigInt.zero ||
      value.unscaled > BigInt.from(1000) * BigInt.from(10).pow(value.scale)) {
    throw const FormatException('Gold fineness must be between 1 and 1000.');
  }
  return normalized;
}

/// Normalizes numeric Iranian-market fineness while retaining legacy textual
/// purity labels already present in older backups (for example `18K`). New
/// entry flows validate with [normalizeGoldFineness] and therefore only create
/// exact values in the 1..1000 range.
String normalizeGoldQuantityPurity(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    throw const FormatException('Gold purity cannot be empty.');
  }
  try {
    return normalizeGoldFineness(value);
  } on FormatException {
    return value;
  }
}

String _latinDigits(String input) {
  const source = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
  const target = '01234567890123456789';
  var result = input;
  for (var i = 0; i < source.length; i++) {
    result = result.replaceAll(source[i], target[i]);
  }
  return result;
}

String? _trimOrNull(String? input) {
  final value = input?.trim();
  return value == null || value.isEmpty ? null : value;
}

void _validateTimestamp(DateTime value, String field) {
  if (value.year < 2000 || value.year > 2200) {
    throw FormatException('$field is outside the supported range.');
  }
}
