import '../domain/zar_domain_models.dart';

enum ZarInventorySection { actual, pendingReceive, pendingDeliver }

class ZarInventoryMovement {
  const ZarInventoryMovement({
    required this.settlementId,
    required this.personId,
    required this.direction,
    required this.occurredAt,
    required this.quantityLabel,
  });

  final String settlementId;
  final String personId;
  final ZarSettlementDirection direction;
  final DateTime occurredAt;
  final String quantityLabel;
}

sealed class ZarOperationalInventoryItem {
  const ZarOperationalInventoryItem({
    required this.identity,
    required this.movements,
  });

  final String identity;
  final List<ZarInventoryMovement> movements;
}

class ZarGoldInventoryItem extends ZarOperationalInventoryItem {
  const ZarGoldInventoryItem({
    required super.identity,
    required this.fineness,
    required this.grams,
    required super.movements,
  });

  final String? fineness;
  final String grams;
}

class ZarCoinInventoryItem extends ZarOperationalInventoryItem {
  const ZarCoinInventoryItem({
    required super.identity,
    required this.displayName,
    required this.quantity,
    required super.movements,
  });

  final String displayName;
  final int quantity;
}

class ZarCurrencyInventoryItem extends ZarOperationalInventoryItem {
  const ZarCurrencyInventoryItem({
    required super.identity,
    required this.code,
    required this.decimalAmount,
    required super.movements,
  });

  final String code;
  final String decimalAmount;
}

class ZarOperationalInventoryProjection {
  const ZarOperationalInventoryProjection({
    required this.goldInventory,
    required this.coinInventory,
    required this.currencyInventory,
    required this.cashInventory,
    required this.pendingReceive,
    required this.pendingDeliver,
  });

  final List<ZarGoldInventoryItem> goldInventory;
  final List<ZarCoinInventoryItem> coinInventory;
  final List<ZarCurrencyInventoryItem> currencyInventory;
  final List<ZarCurrencyInventoryItem> cashInventory;
  final List<ZarOperationalInventoryItem> pendingReceive;
  final List<ZarOperationalInventoryItem> pendingDeliver;
}

/// Projects actual and pending operational quantities from settlement state.
/// Deals never participate. Completed movements are summed from current stored
/// state, so refresh/restart cannot apply a movement more than once.
class ZarOperationalInventoryProjector {
  const ZarOperationalInventoryProjector();

  ZarOperationalInventoryProjection project({
    required Iterable<ZarSettlement> settlements,
  }) {
    final actual = _InventoryAccumulator();
    final pendingReceive = _InventoryAccumulator();
    final pendingDeliver = _InventoryAccumulator();

    for (final settlement in settlements) {
      switch (settlement.status) {
        case ZarSettlementStatus.completed:
          actual.add(
            settlement,
            sign: settlement.direction == ZarSettlementDirection.receive
                ? 1
                : -1,
          );
        case ZarSettlementStatus.open:
          (settlement.direction == ZarSettlementDirection.receive
                  ? pendingReceive
                  : pendingDeliver)
              .add(settlement, sign: 1);
        case ZarSettlementStatus.cancelled:
          break;
      }
    }

    final actualItems = actual.items;
    return ZarOperationalInventoryProjection(
      goldInventory: actualItems.whereType<ZarGoldInventoryItem>().toList(),
      coinInventory: actualItems.whereType<ZarCoinInventoryItem>().toList(),
      currencyInventory: actualItems
          .whereType<ZarCurrencyInventoryItem>()
          .where((item) => item.code != 'TOMAN')
          .toList(),
      cashInventory: actualItems
          .whereType<ZarCurrencyInventoryItem>()
          .where((item) => item.code == 'TOMAN')
          .toList(),
      pendingReceive: pendingReceive.items,
      pendingDeliver: pendingDeliver.items,
    );
  }
}

class _InventoryAccumulator {
  final Map<String?, _DecimalAccumulator> _gold = {};
  final Map<String, _DecimalAccumulator> _currencies = {};
  final Map<String, _CoinAccumulator> _coins = {};
  final Map<String, List<ZarInventoryMovement>> _movements = {};

  void add(ZarSettlement settlement, {required int sign}) {
    switch (settlement.amount) {
      case ZarGoldAssetAmount(:final value):
        final key = 'gold:${value.purity ?? 'unknown'}';
        final grams = zarGoldWeightInGrams(value.decimal, value.unit);
        _gold
            .putIfAbsent(value.purity, _DecimalAccumulator.new)
            .add(grams, sign);
        _addMovement(settlement, key, '$grams گرم');
      case ZarCurrencyAssetAmount(:final value):
        final key = 'currency:${value.code}';
        _currencies
            .putIfAbsent(value.code, _DecimalAccumulator.new)
            .add(
              _minorUnitsToDecimal(value.minorUnits, value.minorUnitScale),
              sign,
            );
        _addMovement(
          settlement,
          key,
          '${value.code} ${_minorUnitsToDecimal(value.minorUnits, value.minorUnitScale)}',
        );
      case ZarCoinBundleAmount(:final lines):
        for (final line in lines) {
          final identity =
              '${line.coinTypeId}|${line.weightPerPieceGrams ?? ''}|${line.fineness ?? ''}';
          final key = 'coin:$identity';
          _coins
                  .putIfAbsent(
                    identity,
                    () => _CoinAccumulator(
                      line.coinTypeNameSnapshot,
                      line.weightPerPieceGrams,
                      line.fineness,
                    ),
                  )
                  .quantity +=
              sign * line.quantity;
          _addMovement(settlement, key, '${line.quantity} عدد');
        }
    }
  }

  void _addMovement(ZarSettlement settlement, String key, String label) {
    _movements
        .putIfAbsent(key, () => [])
        .add(
          ZarInventoryMovement(
            settlementId: settlement.id,
            personId: settlement.personId,
            direction: settlement.direction,
            occurredAt: settlement.completedAt ?? settlement.scheduledAt,
            quantityLabel: label,
          ),
        );
  }

  List<ZarOperationalInventoryItem> get items {
    final result = <ZarOperationalInventoryItem>[
      ..._gold.entries.where((entry) => !entry.value.isZero).map((entry) {
        final key = 'gold:${entry.key ?? 'unknown'}';
        return ZarGoldInventoryItem(
          identity: key,
          fineness: entry.key,
          grams: entry.value.decimal,
          movements: _sortedMovements(key),
        );
      }),
      ..._coins.entries.where((entry) => entry.value.quantity != 0).map((
        entry,
      ) {
        final key = 'coin:${entry.key}';
        return ZarCoinInventoryItem(
          identity: key,
          displayName: entry.value.label,
          quantity: entry.value.quantity,
          movements: _sortedMovements(key),
        );
      }),
      ..._currencies.entries.where((entry) => !entry.value.isZero).map((entry) {
        final key = 'currency:${entry.key}';
        return ZarCurrencyInventoryItem(
          identity: key,
          code: entry.key,
          decimalAmount: entry.value.decimal,
          movements: _sortedMovements(key),
        );
      }),
    ];
    result.sort((a, b) => a.identity.compareTo(b.identity));
    return List.unmodifiable(result);
  }

  List<ZarInventoryMovement> _sortedMovements(String key) => List.unmodifiable(
    [...?_movements[key]]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
  );
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

class _DecimalAccumulator {
  BigInt _unscaled = BigInt.zero;
  int _scale = 0;

  bool get isZero => _unscaled == BigInt.zero;

  void add(String value, int sign) {
    final decimal = ZarExactDecimal.parse(value);
    final target = decimal.scale > _scale ? decimal.scale : _scale;
    _unscaled =
        _unscaled * BigInt.from(10).pow(target - _scale) +
        decimal.unscaled *
            BigInt.from(sign) *
            BigInt.from(10).pow(target - decimal.scale);
    _scale = target;
  }

  String get decimal {
    var value = _unscaled;
    var scale = _scale;
    while (scale > 0 && value.remainder(BigInt.from(10)) == BigInt.zero) {
      value ~/= BigInt.from(10);
      scale--;
    }
    if (scale == 0) return value.toString();
    final digits = value.abs().toString().padLeft(scale + 1, '0');
    final split = digits.length - scale;
    return '${value.isNegative ? '-' : ''}${digits.substring(0, split)}.${digits.substring(split)}';
  }
}

String _minorUnitsToDecimal(int units, int scale) {
  if (scale == 0) return units.toString();
  final digits = units.toString().padLeft(scale + 1, '0');
  final split = digits.length - scale;
  final fraction = digits.substring(split).replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty
      ? digits.substring(0, split)
      : '${digits.substring(0, split)}.$fraction';
}
