import 'zar_reminder_plan.dart';

enum ZarAssetType { gold, currency }

enum ZarDealType { buy, sell }

enum ZarDealStatus { active, completed, cancelled }

enum ZarSettlementDirection { receive, deliver }

enum ZarSettlementStatus { open, completed, cancelled }

enum ZarGoldUnit { gram, mesghal, coin, item }

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
      default:
        throw const FormatException('Unsupported deal pricing kind.');
    }
  }
}

class ZarGoldDealPricing extends ZarDealPricing {
  ZarGoldDealPricing({
    required Object fineness,
    String inputWeight = '1',
    this.inputWeightUnit = ZarGoldUnit.gram,
    this.priceUnit = ZarGoldUnit.gram,
    ZarTomanAmount? pricePerUnitToman,
    ZarTomanAmount? pricePerGramToman,
    required this.totalToman,
  }) : fineness = normalizeGoldFineness(fineness.toString()),
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
    required String inputWeight,
    required ZarGoldUnit inputWeightUnit,
    required ZarGoldUnit priceUnit,
    required ZarTomanAmount pricePerUnitToman,
  }) {
    final input = ZarExactDecimal.parse(inputWeight);
    final price = ZarExactDecimal.parse(
      pricePerUnitToman.wholeTomans.toString(),
    );
    final total = switch ((inputWeightUnit, priceUnit)) {
      (ZarGoldUnit.gram, ZarGoldUnit.gram) ||
      (
        ZarGoldUnit.mesghal,
        ZarGoldUnit.mesghal,
      ) => input.multiply(price).roundToWhole(),
      (ZarGoldUnit.mesghal, ZarGoldUnit.gram) =>
        input
            .multiply(ZarExactDecimal.parse(zarGramsPerMesghal))
            .multiply(price)
            .roundToWhole(),
      (ZarGoldUnit.gram, ZarGoldUnit.mesghal) =>
        input
            .multiply(price)
            .divide(ZarExactDecimal.parse(zarGramsPerMesghal), decimalPlaces: 0)
            .roundToWhole(),
      _ => throw const FormatException(
        'Gold pricing supports gram or mesghal only.',
      ),
    };
    return ZarGoldDealPricing(
      fineness: fineness,
      inputWeight: inputWeight,
      inputWeightUnit: inputWeightUnit,
      priceUnit: priceUnit,
      pricePerUnitToman: pricePerUnitToman,
      totalToman: ZarTomanAmount(total),
    );
  }

  final String fineness;
  final String inputWeight;
  final ZarGoldUnit inputWeightUnit;
  final ZarGoldUnit priceUnit;
  final ZarTomanAmount pricePerUnitToman;
  String get normalizedWeightGrams =>
      zarGoldWeightInGrams(inputWeight, inputWeightUnit);
  String get equivalentWeightMesghal =>
      zarGoldWeightInMesghal(normalizedWeightGrams);

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
    'inputWeight': inputWeight,
    'inputWeightUnit': inputWeightUnit.name,
    'priceUnit': priceUnit.name,
    'pricePerUnitToman': pricePerUnitToman.toMap(),
    'totalToman': totalToman.toMap(),
  };

  factory ZarGoldDealPricing.fromMap(Map<String, Object?> map) =>
      ZarGoldDealPricing(
        fineness: map['fineness']!,
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
    }
  }
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
