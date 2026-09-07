import 'zar_domain_models.dart';

enum ZarPaymentAllocationTarget { deal, settlement }

/// An explicit user choice. Absence of this relationship means free movement.
/// This is independent of the legacy physical-movement `dealId` relationship.
class ZarPaymentAllocation {
  ZarPaymentAllocation({
    required this.settlementId,
    required this.targetType,
    required this.targetId,
    required this.amount,
  }) {
    if (settlementId.trim().isEmpty || targetId.trim().isEmpty) {
      throw const FormatException('Allocation references must not be empty.');
    }
    if (targetType == ZarPaymentAllocationTarget.settlement &&
        targetId == settlementId) {
      throw const FormatException('A payment cannot allocate to itself.');
    }
  }

  final String settlementId;
  final ZarPaymentAllocationTarget targetType;
  final String targetId;
  final ZarTomanAmount amount;

  Map<String, Object?> toMap() => {
    'settlementId': settlementId,
    'targetType': targetType.name,
    'targetId': targetId,
    'amountToman': amount.wholeTomans,
  };

  factory ZarPaymentAllocation.fromMap(Map<String, Object?> map) =>
      ZarPaymentAllocation(
        settlementId: map['settlementId']! as String,
        targetType: ZarPaymentAllocationTarget.values.byName(
          map['targetType']! as String,
        ),
        targetId: map['targetId']! as String,
        amount: ZarTomanAmount(map['amountToman']! as int),
      );
}

/// Validates references and reserved amounts before any persistence mutation.
void validateZarPaymentAllocations({
  required Iterable<ZarDeal> deals,
  required Iterable<ZarSettlement> settlements,
  required Iterable<ZarPaymentAllocation> allocations,
}) {
  final dealMap = {for (final item in deals) item.id: item};
  final movementMap = {for (final item in settlements) item.id: item};
  final rows = allocations.toList();
  final sources = rows.map((item) => item.settlementId).toSet();
  final seen = <String>{};
  final sourceTotals = <String, BigInt>{};
  final targetTotals = <String, BigInt>{};
  for (final row in rows) {
    final source = movementMap[row.settlementId];
    final sourceAmount = source == null ? null : zarWholeToman(source.amount);
    if (source == null || sourceAmount == null) {
      throw const FormatException(
        'Allocation source must be a whole Toman movement.',
      );
    }
    final key = '${row.targetType.name}:${row.targetId}';
    if (!seen.add('${row.settlementId}:$key')) {
      throw const FormatException('Duplicate allocation.');
    }
    late String person;
    late String business;
    late ZarSettlementDirection direction;
    late BigInt targetAmount;
    switch (row.targetType) {
      case ZarPaymentAllocationTarget.deal:
        final target = dealMap[row.targetId];
        if (target == null || target.pricing == null) {
          throw const FormatException(
            'Allocation target requires a priced deal.',
          );
        }
        person = target.personId;
        business = target.businessId;
        direction = target.type == ZarDealType.buy
            ? ZarSettlementDirection.deliver
            : ZarSettlementDirection.receive;
        targetAmount = BigInt.from(target.pricing!.totalToman.wholeTomans);
      case ZarPaymentAllocationTarget.settlement:
        final target = movementMap[row.targetId];
        final amount = target == null ? null : zarWholeToman(target.amount);
        if (target == null || amount == null || sources.contains(target.id)) {
          throw const FormatException(
            'Select an original Toman obligation, not an allocated movement.',
          );
        }
        person = target.personId;
        business = target.businessId;
        direction = target.direction;
        targetAmount = amount;
    }
    if (source.personId != person ||
        source.businessId != business ||
        source.direction != direction) {
      throw const FormatException(
        'Allocation person, business or direction mismatch.',
      );
    }
    final assigned = BigInt.from(row.amount.wholeTomans);
    sourceTotals[source.id] =
        (sourceTotals[source.id] ?? BigInt.zero) + assigned;
    if (sourceTotals[source.id]! > sourceAmount) {
      throw const FormatException('Allocation exceeds source amount.');
    }
    if (source.status != ZarSettlementStatus.cancelled) {
      targetTotals[key] = (targetTotals[key] ?? BigInt.zero) + assigned;
      if (targetTotals[key]! > targetAmount) {
        throw const FormatException('Allocation exceeds target amount.');
      }
    }
  }
}

BigInt? zarWholeToman(ZarAssetAmount amount) {
  if (amount is! ZarCurrencyAssetAmount || amount.value.code != 'TOMAN') {
    return null;
  }
  final minor = BigInt.from(amount.value.minorUnits);
  final divisor = BigInt.from(10).pow(amount.value.minorUnitScale);
  return minor.remainder(divisor) == BigInt.zero ? minor ~/ divisor : null;
}
