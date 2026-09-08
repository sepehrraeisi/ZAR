import '../domain/zar_domain_models.dart';

enum ZarCustomerPositionSide { receive, deliver }

sealed class ZarCustomerPositionItem {
  const ZarCustomerPositionItem();
}

class ZarCustomerGoldPosition extends ZarCustomerPositionItem {
  const ZarCustomerGoldPosition({required this.fineness, required this.grams});

  /// Null means the source settlement did not record a purity value.
  final String? fineness;
  final String grams;
}

class ZarCustomerCurrencyPosition extends ZarCustomerPositionItem {
  const ZarCustomerCurrencyPosition({
    required this.code,
    required this.decimalAmount,
  });

  final String code;
  final String decimalAmount;
}

class ZarCustomerCoinPosition extends ZarCustomerPositionItem {
  const ZarCustomerCoinPosition({
    required this.identity,
    required this.displayName,
    required this.quantity,
  });
  final String identity;
  final String displayName;
  final int quantity;
}

class ZarCustomerPosition {
  const ZarCustomerPosition({
    required this.receive,
    required this.deliver,
    required this.buyCount,
    required this.sellCount,
    required this.receiveCount,
    required this.deliverCount,
    required this.lastActivityAt,
  });

  const ZarCustomerPosition.empty()
    : receive = const [],
      deliver = const [],
      buyCount = 0,
      sellCount = 0,
      receiveCount = 0,
      deliverCount = 0,
      lastActivityAt = null;

  final List<ZarCustomerPositionItem> receive;
  final List<ZarCustomerPositionItem> deliver;
  final int buyCount;
  final int sellCount;
  final int receiveCount;
  final int deliverCount;
  final DateTime? lastActivityAt;

  int get activityCount => buyCount + sellCount + receiveCount + deliverCount;
}

/// Derives an operational customer view. It never stores or offsets balances,
/// and deals never create obligations.
class ZarCustomerPositionProjector {
  const ZarCustomerPositionProjector();

  ZarCustomerPosition project({
    required String personId,
    required Iterable<ZarDeal> deals,
    required Iterable<ZarSettlement> settlements,
  }) {
    final personDeals = deals.where((item) => item.personId == personId);
    final personSettlements = settlements.where(
      (item) => item.personId == personId,
    );
    final activeSettlements = personSettlements.where(
      (item) => item.status != ZarSettlementStatus.cancelled,
    );
    final open = activeSettlements.where((item) => item.isOpen);

    final buyCount = personDeals
        .where((item) => item.type == ZarDealType.buy)
        .length;
    final sellCount = personDeals
        .where((item) => item.type == ZarDealType.sell)
        .length;
    final receiveCount = activeSettlements
        .where((item) => item.direction == ZarSettlementDirection.receive)
        .length;
    final deliverCount = activeSettlements
        .where((item) => item.direction == ZarSettlementDirection.deliver)
        .length;

    DateTime? lastActivity;
    for (final date in <DateTime>[
      ...personDeals.map((item) => item.dealAt),
      ...personSettlements.map((item) => item.scheduledAt),
    ]) {
      if (lastActivity == null || date.isAfter(lastActivity)) {
        lastActivity = date;
      }
    }

    return ZarCustomerPosition(
      receive: _aggregate(
        open.where((item) => item.direction == ZarSettlementDirection.receive),
      ),
      deliver: _aggregate(
        open.where((item) => item.direction == ZarSettlementDirection.deliver),
      ),
      buyCount: buyCount,
      sellCount: sellCount,
      receiveCount: receiveCount,
      deliverCount: deliverCount,
      lastActivityAt: lastActivity,
    );
  }

  List<ZarCustomerPositionItem> _aggregate(
    Iterable<ZarSettlement> settlements,
  ) {
    final gold = <String?, ZarExactDecimal>{};
    final currencies = <String, _CurrencyAccumulator>{};
    final coins = <String, _CoinAccumulator>{};
    for (final settlement in settlements) {
      switch (settlement.amount) {
        case ZarGoldAssetAmount(:final value):
          // Numeric fineness is normalized by the domain constructor. Retain
          // legacy textual labels losslessly instead of guessing a conversion.
          final fineness = value.purity;
          final grams = ZarExactDecimal.parse(
            zarGoldWeightInGrams(value.decimal, value.unit),
          );
          gold[fineness] = (gold[fineness] ?? ZarExactDecimal.parse('0')).add(
            grams,
          );
        case ZarCurrencyAssetAmount(:final value):
          currencies
              .putIfAbsent(value.code, _CurrencyAccumulator.new)
              .add(value.minorUnits, value.minorUnitScale);
        case ZarCoinBundleAmount(:final lines):
          for (final line in lines) {
            final identity =
                '${line.coinTypeId}|${line.weightPerPieceGrams ?? ''}|${line.fineness ?? ''}';
            coins
                    .putIfAbsent(
                      identity,
                      () => _CoinAccumulator(
                        line.coinTypeNameSnapshot,
                        line.weightPerPieceGrams,
                        line.fineness,
                      ),
                    )
                    .quantity +=
                line.quantity;
          }
      }
    }

    final result = <ZarCustomerPositionItem>[
      ...gold.entries.map(
        (entry) => ZarCustomerGoldPosition(
          fineness: entry.key,
          grams: entry.value.toString(),
        ),
      ),
      ...currencies.entries.map(
        (entry) => ZarCustomerCurrencyPosition(
          code: entry.key,
          decimalAmount: entry.value.decimal,
        ),
      ),
      ...coins.entries.map(
        (entry) => ZarCustomerCoinPosition(
          identity: entry.key,
          displayName: entry.value.label,
          quantity: entry.value.quantity,
        ),
      ),
    ];
    result.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return List.unmodifiable(result);
  }

  String _sortKey(ZarCustomerPositionItem item) => switch (item) {
    ZarCustomerGoldPosition(:final fineness) => '0-${fineness ?? 'unknown'}',
    ZarCustomerCurrencyPosition(:final code) => '1-$code',
    ZarCustomerCoinPosition(:final identity) => '2-$identity',
  };
}

class _CoinAccumulator {
  _CoinAccumulator(this.name, this.weight, this.fineness);
  final String name;
  final String? weight;
  final String? fineness;
  int quantity = 0;
  String get label => [
    name,
    if (weight != null) '$weight گرم',
    if (fineness != null) 'عیار $fineness',
  ].join(' ');
}

class _CurrencyAccumulator {
  BigInt _minorUnits = BigInt.zero;
  int _scale = 0;

  void add(int minorUnits, int scale) {
    if (scale > _scale) {
      _minorUnits *= BigInt.from(10).pow(scale - _scale);
      _scale = scale;
    }
    _minorUnits +=
        BigInt.from(minorUnits) * BigInt.from(10).pow(_scale - scale);
  }

  String get decimal {
    if (_scale == 0) return _minorUnits.toString();
    final digits = _minorUnits.toString().padLeft(_scale + 1, '0');
    final split = digits.length - _scale;
    final fraction = digits.substring(split).replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty
        ? digits.substring(0, split)
        : '${digits.substring(0, split)}.$fraction';
  }
}
