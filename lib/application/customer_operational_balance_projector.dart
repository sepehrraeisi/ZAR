import '../domain/zar_domain_models.dart';
import '../domain/zar_payment_allocation.dart';
import 'customer_position_projector.dart';

/// A typed, derived asset bucket for a person's current operational position.
///
/// These values come from open settlements only. Deal pricing contributes its
/// actual Toman consideration to the financial balance, but a Deal never
/// invents a physical asset obligation.
class ZarCustomerBalanceAssetBucket {
  const ZarCustomerBalanceAssetBucket({
    required this.direction,
    required this.assetType,
    required this.amount,
    this.currencyCode,
    this.goldFineness,
    this.coinIdentity,
    this.displayName,
    this.sourceCount = 0,
  });

  final ZarSettlementDirection direction;
  final ZarAssetType assetType;
  final String amount;
  final String? currencyCode;
  final String? goldFineness;
  final String? coinIdentity;
  final String? displayName;
  final int sourceCount;

  bool get isToman =>
      assetType == ZarAssetType.currency && currencyCode == 'TOMAN';
}

class ZarCustomerTomanObligation {
  const ZarCustomerTomanObligation({
    required this.targetType,
    required this.targetId,
    required this.direction,
    required this.originalToman,
    required this.allocatedToman,
  });

  final ZarPaymentAllocationTarget targetType;
  final String targetId;
  final ZarSettlementDirection direction;
  final BigInt originalToman;
  final BigInt allocatedToman;
  BigInt get remainingToman => originalToman - allocatedToman;
}

class ZarCustomerOperationalBalance {
  ZarCustomerOperationalBalance(
    Iterable<ZarCustomerTomanObligation> values, {
    Iterable<ZarCustomerBalanceAssetBucket> receivableAssetBuckets = const [],
    Iterable<ZarCustomerBalanceAssetBucket> payableAssetBuckets = const [],
  }) : obligations = List.unmodifiable(values),
       receivableAssetBuckets = List.unmodifiable(receivableAssetBuckets),
       payableAssetBuckets = List.unmodifiable(payableAssetBuckets);

  final List<ZarCustomerTomanObligation> obligations;
  final List<ZarCustomerBalanceAssetBucket> receivableAssetBuckets;
  final List<ZarCustomerBalanceAssetBucket> payableAssetBuckets;

  BigInt get receivableToman => _sum(ZarSettlementDirection.receive);
  BigInt get payableToman => _sum(ZarSettlementDirection.deliver);

  List<ZarCustomerBalanceAssetBucket> bucketsFor(
    ZarSettlementDirection direction,
  ) => direction == ZarSettlementDirection.receive
      ? receivableAssetBuckets
      : payableAssetBuckets;

  BigInt _sum(ZarSettlementDirection direction) => obligations
      .where((item) => item.direction == direction)
      .fold(BigInt.zero, (sum, item) => sum + item.remainingToman);
}

/// Reconstructs remaining Toman obligations from one coherent snapshot.
/// Free movements never offset obligations. No replay or persisted totals.
class ZarCustomerOperationalBalanceProjector {
  const ZarCustomerOperationalBalanceProjector();

  ZarCustomerOperationalBalance project({
    required String personId,
    required Iterable<ZarDeal> deals,
    required Iterable<ZarSettlement> settlements,
    required Iterable<ZarPaymentAllocation> allocations,
  }) {
    validateZarPaymentAllocations(
      deals: deals,
      settlements: settlements,
      allocations: allocations,
    );
    final dealById = {for (final deal in deals) deal.id: deal};
    final settlementById = {for (final item in settlements) item.id: item};
    final allocationList = allocations.toList(growable: false);
    final allocationSources = allocationList
        .map((item) => item.settlementId)
        .toSet();
    final allocatedByTarget = <String, BigInt>{};
    final allocatedBySource = <String, BigInt>{};
    final coveredBySource = <String, BigInt>{};
    final seen = <String>{};

    for (final allocation in allocationList) {
      final source = settlementById[allocation.settlementId];
      if (source == null) {
        throw const FormatException('Allocation source is missing.');
      }
      final key = '${allocation.targetType.name}:${allocation.targetId}';
      if (!seen.add('${source.id}:$key')) {
        throw const FormatException('Duplicate payment allocation.');
      }
      final sourceAmount = _toman(source.amount);
      if (sourceAmount == null) {
        throw const FormatException(
          'Financial allocation requires whole Toman.',
        );
      }
      final assigned = BigInt.from(allocation.amount.wholeTomans);
      final sourceTotal =
          (allocatedBySource[source.id] ?? BigInt.zero) + assigned;
      if (sourceTotal > sourceAmount) {
        throw const FormatException('Allocations exceed payment amount.');
      }
      allocatedBySource[source.id] = sourceTotal;

      late String targetPerson;
      late String targetBusiness;
      late ZarSettlementDirection direction;
      late bool cancelled;
      switch (allocation.targetType) {
        case ZarPaymentAllocationTarget.deal:
          final target = dealById[allocation.targetId];
          if (target == null || target.pricing == null) {
            throw const FormatException('Allocation requires a priced deal.');
          }
          targetPerson = target.personId;
          targetBusiness = target.businessId;
          direction = target.type == ZarDealType.buy
              ? ZarSettlementDirection.deliver
              : ZarSettlementDirection.receive;
          cancelled = target.status == ZarDealStatus.cancelled;
        case ZarPaymentAllocationTarget.settlement:
          final target = settlementById[allocation.targetId];
          if (target == null || _toman(target.amount) == null) {
            throw const FormatException(
              'Allocation requires a Toman obligation.',
            );
          }
          if (target.id == source.id) {
            throw const FormatException('Self allocation is not allowed.');
          }
          if (allocationSources.contains(target.id)) {
            throw const FormatException(
              'Select the original obligation instead of an allocated payment.',
            );
          }
          targetPerson = target.personId;
          targetBusiness = target.businessId;
          direction = target.direction;
          cancelled = target.status == ZarSettlementStatus.cancelled;
      }
      if (source.personId != targetPerson ||
          source.businessId != targetBusiness ||
          source.direction != direction) {
        throw const FormatException(
          'Allocation person, business or direction mismatch.',
        );
      }
      if (!cancelled && source.status != ZarSettlementStatus.cancelled) {
        coveredBySource[source.id] =
            (coveredBySource[source.id] ?? BigInt.zero) + assigned;
      }
      if (source.personId != personId ||
          cancelled ||
          source.status != ZarSettlementStatus.completed) {
        continue;
      }
      allocatedByTarget[key] =
          (allocatedByTarget[key] ?? BigInt.zero) + assigned;
    }

    final result = <ZarCustomerTomanObligation>[];
    void add(
      ZarPaymentAllocationTarget type,
      String id,
      ZarSettlementDirection direction,
      BigInt total,
    ) {
      final allocated = allocatedByTarget['${type.name}:$id'] ?? BigInt.zero;
      if (allocated > total) {
        throw const FormatException('Allocations exceed target obligation.');
      }
      result.add(
        ZarCustomerTomanObligation(
          targetType: type,
          targetId: id,
          direction: direction,
          originalToman: total,
          allocatedToman: allocated,
        ),
      );
    }

    for (final deal in dealById.values) {
      if (deal.personId != personId ||
          deal.status == ZarDealStatus.cancelled ||
          deal.pricing == null) {
        continue;
      }
      add(
        ZarPaymentAllocationTarget.deal,
        deal.id,
        deal.type == ZarDealType.buy
            ? ZarSettlementDirection.deliver
            : ZarSettlementDirection.receive,
        BigInt.from(deal.pricing!.totalToman.wholeTomans),
      );
    }
    for (final settlement in settlementById.values) {
      if (settlement.personId != personId || !settlement.isOpen) continue;
      final amount = _toman(settlement.amount);
      if (amount == null) continue;
      // Legacy dealId does not prove financial allocation or coverage.
      add(
        ZarPaymentAllocationTarget.settlement,
        settlement.id,
        settlement.direction,
        amount - (coveredBySource[settlement.id] ?? BigInt.zero),
      );
    }
    final position = const ZarCustomerPositionProjector().project(
      personId: personId,
      deals: deals,
      settlements: settlements,
    );
    final receivableBuckets = <ZarCustomerBalanceAssetBucket>[];
    final payableBuckets = <ZarCustomerBalanceAssetBucket>[];
    final receivableToman = result
        .where((item) => item.direction == ZarSettlementDirection.receive)
        .fold<BigInt>(BigInt.zero, (sum, item) => sum + item.remainingToman);
    final payableToman = result
        .where((item) => item.direction == ZarSettlementDirection.deliver)
        .fold<BigInt>(BigInt.zero, (sum, item) => sum + item.remainingToman);
    if (receivableToman != BigInt.zero) {
      receivableBuckets.add(
        ZarCustomerBalanceAssetBucket(
          direction: ZarSettlementDirection.receive,
          assetType: ZarAssetType.currency,
          currencyCode: 'TOMAN',
          amount: receivableToman.toString(),
        ),
      );
    }
    if (payableToman != BigInt.zero) {
      payableBuckets.add(
        ZarCustomerBalanceAssetBucket(
          direction: ZarSettlementDirection.deliver,
          assetType: ZarAssetType.currency,
          currencyCode: 'TOMAN',
          amount: payableToman.toString(),
        ),
      );
    }
    for (final item in position.receive) {
      final bucket = _assetBucket(
        item,
        direction: ZarSettlementDirection.receive,
      );
      if (bucket != null && !bucket.isToman) receivableBuckets.add(bucket);
    }
    for (final item in position.deliver) {
      final bucket = _assetBucket(
        item,
        direction: ZarSettlementDirection.deliver,
      );
      if (bucket != null && !bucket.isToman) payableBuckets.add(bucket);
    }
    return ZarCustomerOperationalBalance(
      result,
      receivableAssetBuckets: receivableBuckets,
      payableAssetBuckets: payableBuckets,
    );
  }

  ZarCustomerBalanceAssetBucket? _assetBucket(
    ZarCustomerPositionItem item, {
    required ZarSettlementDirection direction,
  }) => switch (item) {
    ZarCustomerGoldPosition(
      :final fineness,
      :final grams,
      :final sourceCount,
    ) =>
      ZarCustomerBalanceAssetBucket(
        direction: direction,
        assetType: ZarAssetType.gold,
        amount: grams,
        goldFineness: fineness,
        sourceCount: sourceCount,
      ),
    ZarCustomerCurrencyPosition(
      :final code,
      :final decimalAmount,
      :final sourceCount,
    ) =>
      ZarCustomerBalanceAssetBucket(
        direction: direction,
        assetType: ZarAssetType.currency,
        amount: decimalAmount,
        currencyCode: code,
        sourceCount: sourceCount,
      ),
    ZarCustomerCoinPosition(
      :final identity,
      :final displayName,
      :final quantity,
      :final sourceCount,
    ) =>
      ZarCustomerBalanceAssetBucket(
        direction: direction,
        assetType: ZarAssetType.coin,
        amount: quantity.toString(),
        coinIdentity: identity,
        displayName: displayName,
        sourceCount: sourceCount,
      ),
  };

  BigInt? _toman(ZarAssetAmount amount) {
    if (amount is! ZarCurrencyAssetAmount || amount.value.code != 'TOMAN') {
      return null;
    }
    final value = BigInt.from(amount.value.minorUnits);
    final scale = BigInt.from(10).pow(amount.value.minorUnitScale);
    if (value.remainder(scale) != BigInt.zero) return null;
    return value ~/ scale;
  }
}
