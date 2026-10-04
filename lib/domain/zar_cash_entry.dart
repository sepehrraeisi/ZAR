import 'zar_domain_models.dart';

enum ZarCashEntryKind { opening, adjustment, contribution, withdrawal, expense, delivery, reversal }

/// Append-only physical cashbox journal. Customer payments remain settlements;
/// these entries cover opening/counts, own funds and physical deal fulfilment.
class ZarCashEntry {
  ZarCashEntry({
    required this.id,
    required this.businessId,
    required this.kind,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    required this.note,
    this.dealId,
    this.reversesId,
    this.countedQuantity,
    this.expectedQuantity,
  }) {
    if (id.trim().isEmpty || businessId.trim().isEmpty || note.trim().isEmpty) {
      throw const FormatException('Cash entry identity and reason are required.');
    }
    if ((kind == ZarCashEntryKind.delivery) != (dealId != null) ||
        (kind == ZarCashEntryKind.reversal) != (reversesId != null)) {
      throw const FormatException('Invalid cash entry reference.');
    }
    if (kind == ZarCashEntryKind.opening || kind == ZarCashEntryKind.contribution) {
      if (direction != ZarSettlementDirection.receive) {
        throw const FormatException('Opening and contribution must be incoming.');
      }
    }
    if ((kind == ZarCashEntryKind.withdrawal || kind == ZarCashEntryKind.expense) &&
        direction != ZarSettlementDirection.deliver) {
      throw const FormatException('Withdrawal and expense must be outgoing.');
    }
    if ((countedQuantity == null) != (expectedQuantity == null)) {
      throw const FormatException('Both count quantities are required.');
    }
    if (countedQuantity != null) {
      normalizeDecimal(countedQuantity!);
      cashSigned(expectedQuantity!);
      if (kind != ZarCashEntryKind.adjustment) {
        throw const FormatException('Counts require an adjustment.');
      }
    }
  }

  final String id;
  final String businessId;
  final ZarCashEntryKind kind;
  final ZarSettlementDirection direction;
  final ZarAssetAmount amount;
  final DateTime occurredAt;
  final String note;
  final String? dealId;
  final String? reversesId;
  final String? countedQuantity;
  final String? expectedQuantity;

  Map<String, Object?> toMap() => {
    'id': id, 'businessId': businessId, 'kind': kind.name,
    'direction': direction.name, 'amount': amount.toMap(),
    'occurredAt': occurredAt.toUtc().toIso8601String(), 'note': note,
    'dealId': dealId, 'reversesId': reversesId,
    'countedQuantity': countedQuantity, 'expectedQuantity': expectedQuantity,
  };

  factory ZarCashEntry.fromMap(Map<String, Object?> map) => ZarCashEntry(
    id: map['id']! as String, businessId: map['businessId']! as String,
    kind: ZarCashEntryKind.values.byName(map['kind']! as String),
    direction: ZarSettlementDirection.values.byName(map['direction']! as String),
    amount: ZarAssetAmount.fromMap(Map<String, Object?>.from(map['amount']! as Map)),
    occurredAt: DateTime.parse(map['occurredAt']! as String).toUtc(),
    note: map['note']! as String, dealId: map['dealId'] as String?,
    reversesId: map['reversesId'] as String?,
    countedQuantity: map['countedQuantity'] as String?,
    expectedQuantity: map['expectedQuantity'] as String?,
  );
}

/// Canonical, unit-specific quantities used for partial fulfilment and counts.
Map<String, String> cashQuantities(ZarAssetAmount amount) {
  switch (amount) {
    case ZarGoldAssetAmount(:final value):
      return {'gold:${value.purity ?? 'unknown'}': zarGoldWeightInGrams(value.decimal, value.unit)};
    case ZarCurrencyAssetAmount(:final value):
      return {'currency:${value.code}': cashDecimal(BigInt.from(value.minorUnits), value.minorUnitScale)};
    case ZarCoinBundleAmount(:final lines):
      final result = <String, String>{};
      for (final line in lines) {
        final key = 'coin:${line.coinTypeId}|${line.weightPerPieceGrams ?? ''}|${line.fineness ?? ''}';
        result[key] = cashAdd(result[key] ?? '0', line.quantity.toString());
      }
      return result;
  }
}

String cashDecimal(BigInt units, int scale) {
  if (units == BigInt.zero) return '0';
  final sign = units.isNegative ? '-' : '';
  final digits = units.abs().toString().padLeft(scale + 1, '0');
  if (scale == 0) return '$sign$digits';
  final fraction = digits.substring(digits.length - scale).replaceFirst(RegExp(r'0+$'), '');
  return '$sign${digits.substring(0, digits.length - scale)}${fraction.isEmpty ? '' : '.$fraction'}';
}

({BigInt units, int scale}) cashSigned(String value) {
  final negative = value.startsWith('-');
  final parsed = ZarExactDecimal.parse(negative ? value.substring(1) : value);
  return (units: negative ? -parsed.unscaled : parsed.unscaled, scale: parsed.scale);
}

String cashAdd(String left, String right, {int sign = 1}) {
  final a = cashSigned(left), b = cashSigned(right);
  final scale = a.scale > b.scale ? a.scale : b.scale;
  return cashDecimal(a.units * BigInt.from(10).pow(scale - a.scale) +
      b.units * BigInt.from(sign) * BigInt.from(10).pow(scale - b.scale), scale);
}

int cashCompare(String left, String right) => cashSigned(cashAdd(left, right, sign: -1)).units.sign;

/// Rebuild an amount with the same identity. Coin bundles must be split into
/// individual lines before editing a quantity.
ZarAssetAmount cashWithQuantity(ZarAssetAmount template, String quantity) {
  final normalized = normalizeDecimal(quantity);
  switch (template) {
    case ZarGoldAssetAmount(:final value):
      return ZarGoldAssetAmount(ZarGoldQuantity(decimal: normalized, purity: value.purity));
    case ZarCurrencyAssetAmount(:final value):
      final parsed = ZarExactDecimal.parse(normalized);
      if (parsed.scale > value.minorUnitScale) throw const FormatException('Too many decimal places.');
      final units = parsed.unscaled * BigInt.from(10).pow(value.minorUnitScale - parsed.scale);
      if (units > BigInt.from(ZarTomanAmount.maxExactValue)) throw const FormatException('Amount exceeds exact range.');
      return ZarCurrencyAssetAmount(ZarCurrencyAmount(code: value.code, minorUnits: units.toInt(), minorUnitScale: value.minorUnitScale));
    case ZarCoinBundleAmount(:final lines):
      if (lines.length != 1 || normalized.contains('.')) throw const FormatException('Whole single coin quantity required.');
      final value = lines.single;
      return ZarCoinBundleAmount([ZarCoinLine(id: value.id, coinTypeId: value.coinTypeId,
        coinTypeNameSnapshot: value.coinTypeNameSnapshot, quantity: int.parse(normalized),
        weightPerPieceGrams: value.weightPerPieceGrams, fineness: value.fineness)]);
  }
}

Iterable<ZarAssetAmount> cashSplitAssets(ZarAssetAmount amount) sync* {
  if (amount is ZarCoinBundleAmount) {
    for (final line in amount.lines) { yield ZarCoinBundleAmount([line]); }
  } else { yield amount; }
}

Map<String, String> cashDeliveredForDeal(ZarDeal deal, Iterable<ZarCashEntry> entries,
    Iterable<ZarSettlement> settlements) {
  final result = <String, String>{};
  final reversed = entries.where((e) => e.reversesId != null).map((e) => e.reversesId).toSet();
  void add(ZarAssetAmount amount) {
    for (final q in cashQuantities(amount).entries) {
      result[q.key] = cashAdd(result[q.key] ?? '0', q.value);
    }
  }
  for (final entry in entries) {
    if (entry.dealId == deal.id && !reversed.contains(entry.id)) add(entry.amount);
  }
  final direction = deal.type == ZarDealType.buy ? ZarSettlementDirection.receive : ZarSettlementDirection.deliver;
  final keys = cashQuantities(deal.amount).keys.toSet();
  for (final s in settlements) {
    if (s.dealId == deal.id && s.personId == deal.personId && s.businessId == deal.businessId &&
        s.direction == direction && s.status == ZarSettlementStatus.completed) {
      for (final q in cashQuantities(s.amount).entries) {
        if (keys.contains(q.key)) result[q.key] = cashAdd(result[q.key] ?? '0', q.value);
      }
    }
  }
  return result;
}

void validateCashEntries({required Iterable<ZarCashEntry> entries,
    required Iterable<ZarDeal> deals, required Iterable<ZarSettlement> settlements}) {
  final list = entries.toList();
  final byId = {for (final e in list) e.id: e};
  if (byId.length != list.length) throw const FormatException('Duplicate cash entry.');
  final settlementIds = settlements.map((s) => s.id).toSet();
  if (list.any((e) => settlementIds.contains(e.id))) throw const FormatException('Duplicate source identity.');
  final dealMap = {for (final d in deals) d.id: d};
  final reversed = <String>{};
  final openings = <String>{};
  for (final e in list) {
    if (e.kind == ZarCashEntryKind.opening) {
      for (final key in cashQuantities(e.amount).keys) {
        if (!openings.add('${e.businessId}:$key')) throw const FormatException('Opening already exists for this asset.');
      }
    }
    if (e.reversesId != null) {
      final original = byId[e.reversesId];
      if (original == null || original.kind == ZarCashEntryKind.reversal ||
          original.kind == ZarCashEntryKind.opening || !reversed.add(original.id) ||
          e.businessId != original.businessId || e.direction == original.direction ||
          e.occurredAt.isBefore(original.occurredAt)) {
        throw const FormatException('Invalid reversal.');
      }
      final quantities = cashQuantities(original.amount), reverse = cashQuantities(e.amount);
      if (quantities.length != reverse.length || quantities.entries.any((q) => reverse[q.key] != q.value)) {
        throw const FormatException('Reversal must exactly match the original.');
      }
    }
    if (e.dealId != null) {
      final deal = dealMap[e.dealId];
      if (deal == null || deal.businessId != e.businessId ||
          e.direction != (deal.type == ZarDealType.buy ? ZarSettlementDirection.receive : ZarSettlementDirection.deliver) ||
          !cashQuantities(deal.amount).keys.toSet().containsAll(cashQuantities(e.amount).keys)) {
        throw const FormatException('Delivery does not match deal.');
      }
    }
    if (e.countedQuantity != null) {
      final q = cashQuantities(e.amount);
      if (q.length != 1) throw const FormatException('Count requires one asset.');
      final difference = cashAdd(e.countedQuantity!, e.expectedQuantity!, sign: -1);
      final signed = e.direction == ZarSettlementDirection.receive ? q.values.single : '-${q.values.single}';
      if (q.length != 1 || cashCompare(difference, signed) != 0) throw const FormatException('Count difference mismatch.');
    }
  }
  for (final deal in dealMap.values) {
    // Legacy links can be inconsistent; new journal deliveries may never exceed
    // the deal. Preserve legacy data without silently manufacturing a repair.
    if (!list.any((e) => e.dealId == deal.id && !reversed.contains(e.id))) continue;
    final delivered = cashDeliveredForDeal(deal, list, settlements);
    final quantities = cashQuantities(deal.amount);
    if (delivered.entries.any((q) => cashCompare(q.value, quantities[q.key] ?? '0') > 0)) {
      throw const FormatException('Delivery exceeds remaining deal quantity.');
    }
  }
}

/// Additional checks for a new write; historical restore may include cancelled
/// deals with physical movements that must remain in the journal.
void validateNewCashEntry(ZarCashEntry entry, Iterable<ZarCashEntry> existing,
    Iterable<ZarDeal> deals, Iterable<ZarSettlement> settlements) {
  if (entry.dealId != null) {
    final deal = deals.where((d) => d.id == entry.dealId).firstOrNull;
    if (deal == null || deal.status == ZarDealStatus.cancelled || entry.occurredAt.isBefore(deal.dealAt)) {
      throw const FormatException('این معامله قابل تحویل نیست یا تاریخ تحویل قبل از معامله است.');
    }
  }
  if (entry.kind == ZarCashEntryKind.opening) {
    final keys = cashQuantities(entry.amount).keys.toSet();
    if (existing.any((e) => e.businessId == entry.businessId && cashQuantities(e.amount).keys.any(keys.contains))) {
      throw const FormatException('برای این دارایی گردش ثبت شده است؛ از شمارش و تطبیق استفاده کنید.');
    }
  }
  validateCashEntries(entries: [...existing, entry], deals: deals, settlements: settlements);
}
