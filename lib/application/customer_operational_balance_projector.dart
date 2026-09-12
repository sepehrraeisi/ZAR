import '../domain/zar_domain_models.dart';
import '../domain/zar_payment_allocation.dart';

/// A typed, derived asset bucket for a person's current operational position.
///
/// These values are derived from the canonical counterparty projector. They
/// represent a net position for one exact asset identity.
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

  /// Stable key shared with the canonical ledger so a bucket can be opened
  /// without reconstructing its identity in presentation code.
  String get assetKey => switch (assetType) {
    ZarAssetType.currency =>
      'currency:${(currencyCode ?? 'OTHER').toUpperCase()}',
    ZarAssetType.gold => 'gold:${goldFineness ?? 'unknown'}',
    ZarAssetType.coin => 'coin:${coinIdentity ?? ''}',
  };

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
    bool projectedAssetBuckets = false,
  }) : obligations = List.unmodifiable(values),
       receivableAssetBuckets = List.unmodifiable(receivableAssetBuckets),
       payableAssetBuckets = List.unmodifiable(payableAssetBuckets),
       _projectedAssetBuckets = projectedAssetBuckets;

  final List<ZarCustomerTomanObligation> obligations;
  final List<ZarCustomerBalanceAssetBucket> receivableAssetBuckets;
  final List<ZarCustomerBalanceAssetBucket> payableAssetBuckets;
  final bool _projectedAssetBuckets;

  /// Returns the net Toman position when this instance came from the
  /// canonical projector. Hand-built presentation fixtures without projected
  /// buckets retain the historical obligation-based behavior.
  BigInt get receivableToman => _projectedAssetBuckets
      ? _sumTomanBucket(receivableAssetBuckets)
      : _sum(ZarSettlementDirection.receive);
  BigInt get payableToman => _projectedAssetBuckets
      ? _sumTomanBucket(payableAssetBuckets)
      : _sum(ZarSettlementDirection.deliver);

  List<ZarCustomerBalanceAssetBucket> bucketsFor(
    ZarSettlementDirection direction,
  ) => direction == ZarSettlementDirection.receive
      ? receivableAssetBuckets
      : payableAssetBuckets;

  BigInt _sum(ZarSettlementDirection direction) => obligations
      .where((item) => item.direction == direction)
      .fold(BigInt.zero, (sum, item) => sum + item.remainingToman);

  BigInt _sumTomanBucket(List<ZarCustomerBalanceAssetBucket> buckets) {
    for (final bucket in buckets) {
      if (bucket.isToman) return BigInt.parse(bucket.amount);
    }
    return BigInt.zero;
  }
}

/// Reconstructs a person's current operational position from one coherent
/// snapshot.  The [obligations] list remains a gross, typed target list used
/// by explicit allocation UI; current buckets come from the canonical ledger
/// projector below and therefore include completed movements exactly once.
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
    final ledger = const ZarCustomerLedgerProjector().project(
      personId: personId,
      deals: deals,
      settlements: settlements,
    );
    return ZarCustomerOperationalBalance(
      result,
      receivableAssetBuckets: ledger.receivableAssetBuckets,
      payableAssetBuckets: ledger.payableAssetBuckets,
      projectedAssetBuckets: true,
    );
  }

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

/// Internal source kind used by the derived counterparty statement. It is
/// intentionally not exposed as accounting terminology in the UI.
enum ZarCustomerLedgerSourceType { deal, settlement }

/// Derived status for a commercial Deal's recorded consideration. It never
/// changes the Deal lifecycle; it only explains how much of its Toman
/// consideration is covered by linked completed movements.
enum ZarCustomerDealAccountingStatus {
  unpriced,
  unsettled,
  partiallySettled,
  settled,
  cancelled,
}

/// A traceable, signed-by-direction posting derived from a source record.
/// [direction] means the resulting customer position: receive means the
/// customer owes ZAR+, deliver means ZAR+ owes the customer.
class ZarCustomerLedgerPosting {
  const ZarCustomerLedgerPosting({
    required this.sourceType,
    required this.sourceRecordId,
    required this.personId,
    required this.businessId,
    required this.direction,
    required this.assetType,
    required this.assetKey,
    required this.amount,
    required this.occurredAt,
    this.currencyCode,
    this.goldFineness,
    this.coinIdentity,
    this.displayName,
    this.sourceLabel,
  });

  final ZarCustomerLedgerSourceType sourceType;
  final String sourceRecordId;
  final String personId;
  final String businessId;
  final ZarSettlementDirection direction;
  final ZarAssetType assetType;
  final String assetKey;
  final String amount;
  final DateTime occurredAt;
  final String? currencyCode;
  final String? goldFineness;
  final String? coinIdentity;
  final String? displayName;

  /// Persian operation label used by traceability views. It is presentation
  /// metadata derived from the source record, not a second business state.
  final String? sourceLabel;
}

/// One gross source line plus the running position after that line.
class ZarCustomerLedgerStatementLine {
  const ZarCustomerLedgerStatementLine({
    required this.posting,
    required this.runningDirection,
    required this.runningAmount,
  });

  final ZarCustomerLedgerPosting posting;
  final ZarSettlementDirection? runningDirection;
  final String runningAmount;
}

/// Canonical derived counterparty accounting state. Nothing is persisted:
/// every value can be traced back to a Deal or completed Settlement.
class ZarCustomerLedgerProjection {
  const ZarCustomerLedgerProjection({
    required this.postings,
    required this.receivableAssetBuckets,
    required this.payableAssetBuckets,
  });

  final List<ZarCustomerLedgerPosting> postings;
  final List<ZarCustomerBalanceAssetBucket> receivableAssetBuckets;
  final List<ZarCustomerBalanceAssetBucket> payableAssetBuckets;

  /// Returns all gross movements in chronological order with the exact
  /// running position for that movement's asset identity.
  List<ZarCustomerLedgerStatementLine> statementLines() {
    final receive = <String, ZarExactDecimal>{};
    final deliver = <String, ZarExactDecimal>{};
    return List.unmodifiable(
      postings.map((posting) {
        final receives =
            receive[posting.assetKey] ?? ZarExactDecimal.parse('0');
        final delivers =
            deliver[posting.assetKey] ?? ZarExactDecimal.parse('0');
        final nextReceives = posting.direction == ZarSettlementDirection.receive
            ? receives.add(ZarExactDecimal.parse(posting.amount))
            : receives;
        final nextDelivers = posting.direction == ZarSettlementDirection.deliver
            ? delivers.add(ZarExactDecimal.parse(posting.amount))
            : delivers;
        receive[posting.assetKey] = nextReceives;
        deliver[posting.assetKey] = nextDelivers;
        final comparison = _compareExact(nextReceives, nextDelivers);
        return ZarCustomerLedgerStatementLine(
          posting: posting,
          runningDirection: comparison == 0
              ? null
              : comparison > 0
              ? ZarSettlementDirection.receive
              : ZarSettlementDirection.deliver,
          runningAmount: comparison == 0
              ? '0'
              : _exactDifference(
                  comparison > 0 ? nextReceives : nextDelivers,
                  comparison > 0 ? nextDelivers : nextReceives,
                ),
        );
      }),
    );
  }

  List<ZarCustomerLedgerStatementLine> statementFor(String assetKey) {
    final rows = postings.where((item) => item.assetKey == assetKey).toList()
      ..sort(_comparePosting);
    var receive = ZarExactDecimal.parse('0');
    var deliver = ZarExactDecimal.parse('0');
    return List.unmodifiable(
      rows.map((posting) {
        if (posting.direction == ZarSettlementDirection.receive) {
          receive = receive.add(ZarExactDecimal.parse(posting.amount));
        } else {
          deliver = deliver.add(ZarExactDecimal.parse(posting.amount));
        }
        final comparison = _compareExact(receive, deliver);
        return ZarCustomerLedgerStatementLine(
          posting: posting,
          runningDirection: comparison == 0
              ? null
              : comparison > 0
              ? ZarSettlementDirection.receive
              : ZarSettlementDirection.deliver,
          runningAmount: comparison == 0
              ? '0'
              : _exactDifference(
                  comparison > 0 ? receive : deliver,
                  comparison > 0 ? deliver : receive,
                ),
        );
      }),
    );
  }

  List<ZarCustomerLedgerStatementLine> linesForSource(String sourceRecordId) =>
      List.unmodifiable(
        statementLines().where(
          (line) => line.posting.sourceRecordId == sourceRecordId,
        ),
      );
}

/// Projects counterparty positions from historical priced Deals and actual
/// completed Settlement movements. Open/cancelled Settlements are excluded.
/// No allocation heuristic is used; an explicit allocation remains useful as
/// a persisted relationship, but the completed source is applied once here.
class ZarCustomerLedgerProjector {
  const ZarCustomerLedgerProjector();

  ZarCustomerDealAccountingStatus accountingStatusForDeal({
    required ZarDeal deal,
    required Iterable<ZarSettlement> settlements,
  }) {
    if (deal.status == ZarDealStatus.cancelled) {
      return ZarCustomerDealAccountingStatus.cancelled;
    }
    final pricing = deal.pricing;
    if (pricing == null || pricing.totalToman.wholeTomans <= 0) {
      return ZarCustomerDealAccountingStatus.unpriced;
    }
    final expectedDirection = deal.type == ZarDealType.buy
        ? ZarSettlementDirection.deliver
        : ZarSettlementDirection.receive;
    var covered = BigInt.zero;
    for (final settlement in settlements) {
      if (settlement.dealId != deal.id ||
          settlement.status != ZarSettlementStatus.completed ||
          settlement.direction != expectedDirection) {
        continue;
      }
      final value = zarWholeToman(settlement.amount);
      if (value != null) covered += value;
    }
    final total = BigInt.from(pricing.totalToman.wholeTomans);
    if (covered >= total) return ZarCustomerDealAccountingStatus.settled;
    if (covered > BigInt.zero) {
      return ZarCustomerDealAccountingStatus.partiallySettled;
    }
    return ZarCustomerDealAccountingStatus.unsettled;
  }

  ZarCustomerLedgerProjection project({
    required String personId,
    required Iterable<ZarDeal> deals,
    required Iterable<ZarSettlement> settlements,
    DateTime? asOf,
  }) {
    final postings = <ZarCustomerLedgerPosting>[];
    for (final deal in deals) {
      if (deal.personId != personId ||
          deal.status == ZarDealStatus.cancelled ||
          deal.pricing == null ||
          _after(deal.dealAt, asOf)) {
        continue;
      }
      postings.add(
        ZarCustomerLedgerPosting(
          sourceType: ZarCustomerLedgerSourceType.deal,
          sourceRecordId: deal.id,
          personId: deal.personId,
          businessId: deal.businessId,
          direction: deal.type == ZarDealType.sell
              ? ZarSettlementDirection.receive
              : ZarSettlementDirection.deliver,
          assetType: ZarAssetType.currency,
          assetKey: 'currency:TOMAN',
          currencyCode: 'TOMAN',
          amount: deal.pricing!.totalToman.wholeTomans.toString(),
          occurredAt: deal.dealAt,
          sourceLabel: deal.type == ZarDealType.buy ? 'خرید' : 'فروش',
        ),
      );
    }
    for (final settlement in settlements) {
      final occurredAt = settlement.completedAt;
      if (settlement.personId != personId ||
          settlement.status != ZarSettlementStatus.completed ||
          occurredAt == null ||
          _after(occurredAt, asOf)) {
        continue;
      }
      _addSettlementPostings(postings, settlement, occurredAt);
    }
    postings.sort(_comparePosting);
    final net = _net(postings);
    return ZarCustomerLedgerProjection(
      postings: List.unmodifiable(postings),
      receivableAssetBuckets: List.unmodifiable(net.receive),
      payableAssetBuckets: List.unmodifiable(net.deliver),
    );
  }

  void _addSettlementPostings(
    List<ZarCustomerLedgerPosting> postings,
    ZarSettlement settlement,
    DateTime occurredAt,
  ) {
    // Receiving an asset reduces what the customer is owed; paying/delivering
    // reduces what the customer owes. Reversing the position naturally models
    // over-receipt and over-payment without a special-case balance flag.
    final balanceDirection =
        settlement.direction == ZarSettlementDirection.receive
        ? ZarSettlementDirection.deliver
        : ZarSettlementDirection.receive;
    switch (settlement.amount) {
      case ZarCurrencyAssetAmount(:final value):
        final code = value.code.toUpperCase();
        postings.add(
          ZarCustomerLedgerPosting(
            sourceType: ZarCustomerLedgerSourceType.settlement,
            sourceRecordId: settlement.id,
            personId: settlement.personId,
            businessId: settlement.businessId,
            direction: balanceDirection,
            assetType: ZarAssetType.currency,
            assetKey: 'currency:$code',
            currencyCode: code,
            amount: _currencyDecimal(value),
            occurredAt: occurredAt,
            sourceLabel: settlement.direction == ZarSettlementDirection.receive
                ? 'دریافت'
                : 'پرداخت',
          ),
        );
      case ZarGoldAssetAmount(:final value):
        final grams = zarGoldWeightInGrams(value.decimal, value.unit);
        final fineness = value.purity;
        postings.add(
          ZarCustomerLedgerPosting(
            sourceType: ZarCustomerLedgerSourceType.settlement,
            sourceRecordId: settlement.id,
            personId: settlement.personId,
            businessId: settlement.businessId,
            direction: balanceDirection,
            assetType: ZarAssetType.gold,
            assetKey: 'gold:${fineness ?? 'unknown'}',
            goldFineness: fineness,
            amount: grams,
            occurredAt: occurredAt,
            sourceLabel: settlement.direction == ZarSettlementDirection.receive
                ? 'دریافت'
                : 'پرداخت',
          ),
        );
      case ZarCoinBundleAmount(:final lines):
        for (final line in lines) {
          final identity = _coinIdentity(line);
          postings.add(
            ZarCustomerLedgerPosting(
              sourceType: ZarCustomerLedgerSourceType.settlement,
              sourceRecordId: settlement.id,
              personId: settlement.personId,
              businessId: settlement.businessId,
              direction: balanceDirection,
              assetType: ZarAssetType.coin,
              assetKey: 'coin:$identity',
              coinIdentity: identity,
              displayName: _coinDisplayName(line),
              amount: line.quantity.toString(),
              occurredAt: occurredAt,
              sourceLabel:
                  settlement.direction == ZarSettlementDirection.receive
                  ? 'دریافت'
                  : 'پرداخت',
            ),
          );
        }
    }
  }

  _NetLedgerBuckets _net(List<ZarCustomerLedgerPosting> postings) {
    final values = <String, _LedgerAccumulator>{};
    for (final posting in postings) {
      final accumulator = values.putIfAbsent(
        posting.assetKey,
        () => _LedgerAccumulator(posting),
      );
      if (posting.direction == ZarSettlementDirection.receive) {
        accumulator.receive = accumulator.receive.add(
          ZarExactDecimal.parse(posting.amount),
        );
        accumulator.receiveCount++;
      } else {
        accumulator.deliver = accumulator.deliver.add(
          ZarExactDecimal.parse(posting.amount),
        );
        accumulator.deliverCount++;
      }
    }
    final receive = <ZarCustomerBalanceAssetBucket>[];
    final deliver = <ZarCustomerBalanceAssetBucket>[];
    for (final value in values.values) {
      final comparison = _compareExact(value.receive, value.deliver);
      if (comparison == 0) continue;
      final receives = comparison > 0;
      final amount = _exactDifference(
        receives ? value.receive : value.deliver,
        receives ? value.deliver : value.receive,
      );
      final bucket = ZarCustomerBalanceAssetBucket(
        direction: receives
            ? ZarSettlementDirection.receive
            : ZarSettlementDirection.deliver,
        assetType: value.template.assetType,
        amount: amount,
        currencyCode: value.template.currencyCode,
        goldFineness: value.template.goldFineness,
        coinIdentity: value.template.coinIdentity,
        displayName: value.template.displayName,
        sourceCount: receives ? value.receiveCount : value.deliverCount,
      );
      (receives ? receive : deliver).add(bucket);
    }
    return _NetLedgerBuckets(receive, deliver);
  }
}

class _LedgerAccumulator {
  _LedgerAccumulator(this.template);
  final ZarCustomerLedgerPosting template;
  ZarExactDecimal receive = ZarExactDecimal.parse('0');
  ZarExactDecimal deliver = ZarExactDecimal.parse('0');
  int receiveCount = 0;
  int deliverCount = 0;
}

class _NetLedgerBuckets {
  const _NetLedgerBuckets(this.receive, this.deliver);
  final List<ZarCustomerBalanceAssetBucket> receive;
  final List<ZarCustomerBalanceAssetBucket> deliver;
}

bool _after(DateTime value, DateTime? asOf) =>
    asOf != null && value.isAfter(asOf);

int _comparePosting(ZarCustomerLedgerPosting a, ZarCustomerLedgerPosting b) {
  final byDate = a.occurredAt.compareTo(b.occurredAt);
  if (byDate != 0) return byDate;
  final bySource = a.sourceRecordId.compareTo(b.sourceRecordId);
  if (bySource != 0) return bySource;
  return a.assetKey.compareTo(b.assetKey);
}

int _compareExact(ZarExactDecimal left, ZarExactDecimal right) {
  final targetScale = left.scale > right.scale ? left.scale : right.scale;
  final leftValue =
      left.unscaled * BigInt.from(10).pow(targetScale - left.scale);
  final rightValue =
      right.unscaled * BigInt.from(10).pow(targetScale - right.scale);
  return leftValue.compareTo(rightValue);
}

String _exactDifference(ZarExactDecimal larger, ZarExactDecimal smaller) {
  final targetScale = larger.scale > smaller.scale
      ? larger.scale
      : smaller.scale;
  var difference =
      larger.unscaled * BigInt.from(10).pow(targetScale - larger.scale) -
      smaller.unscaled * BigInt.from(10).pow(targetScale - smaller.scale);
  var scale = targetScale;
  while (scale > 0 && difference.remainder(BigInt.from(10)) == BigInt.zero) {
    difference ~/= BigInt.from(10);
    scale--;
  }
  if (scale == 0) return difference.toString();
  final digits = difference.toString().padLeft(scale + 1, '0');
  final split = digits.length - scale;
  return '${digits.substring(0, split)}.${digits.substring(split)}';
}

String _currencyDecimal(ZarCurrencyAmount value) {
  if (value.minorUnitScale == 0) return value.minorUnits.toString();
  final digits = value.minorUnits.toString().padLeft(
    value.minorUnitScale + 1,
    '0',
  );
  final split = digits.length - value.minorUnitScale;
  final fraction = digits.substring(split).replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty
      ? digits.substring(0, split)
      : '${digits.substring(0, split)}.$fraction';
}

String _coinIdentity(ZarCoinLine line) =>
    '${line.coinTypeId}|${line.weightPerPieceGrams ?? ''}|${line.fineness ?? ''}';

String _coinDisplayName(ZarCoinLine line) => [
  line.coinTypeNameSnapshot,
  if (line.weightPerPieceGrams != null) '${line.weightPerPieceGrams} گرم',
  if (line.fineness != null) 'عیار ${line.fineness}',
].join(' ');
