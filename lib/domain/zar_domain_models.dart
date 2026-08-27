import 'zar_reminder_plan.dart';

enum ZarAssetType { gold, currency }

enum ZarDealType { buy, sell }

enum ZarDealStatus { active, completed, cancelled }

enum ZarSettlementDirection { receive, deliver }

enum ZarSettlementStatus { open, completed, cancelled }

enum ZarGoldUnit { gram, mesghal, coin, item }

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
    return ZarGoldQuantity._(normalized, unit, _trimOrNull(purity));
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

  factory ZarCurrencyAmount.fromMap(Map<String, Object?> map) => ZarCurrencyAmount(
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
          ZarGoldQuantity.fromMap(Map<String, Object?>.from(map['gold']! as Map)),
        );
      case ZarAssetType.currency:
        return ZarCurrencyAssetAmount(
          ZarCurrencyAmount.fromMap(Map<String, Object?>.from(map['currency']! as Map)),
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
  })  : phone = _trimOrNull(phone),
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
    required this.dealAt,
    this.status = ZarDealStatus.active,
    String? note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : note = _trimOrNull(note) {
    _validateTimestamp(dealAt, 'dealAt');
  }

  final String id;
  final String businessId;
  final ZarDealType type;
  final String personId;
  final ZarAssetAmount amount;
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
  })  : dealId = _trimOrNull(dealId),
        completedBy = _trimOrNull(completedBy),
        note = _trimOrNull(note) {
    _validateTimestamp(scheduledAt, 'scheduledAt');
    if (status == ZarSettlementStatus.completed && completedAt == null) {
      throw const FormatException('Completed settlement requires completedAt.');
    }
    if (status != ZarSettlementStatus.completed && completedAt != null) {
      throw const FormatException('Only completed settlements may have completedAt.');
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
