import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 9, 12, 10);

ZarDeal _deal({
  required ZarDealType type,
  required int totalToman,
  String id = 'deal',
}) => ZarDeal(
  id: id,
  businessId: 'business',
  personId: 'person',
  type: type,
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'USD', minorUnits: 1, minorUnitScale: 0),
  ),
  pricing: ZarCurrencyDealPricing(
    tomanPerUnit: '1',
    totalToman: ZarTomanAmount(totalToman),
  ),
  dealAt: _at,
  createdBy: 'test',
  createdAt: _at,
  updatedAt: _at,
);

ZarSettlement _settlement({
  required ZarSettlementDirection direction,
  required ZarAssetAmount amount,
  String id = 'settlement',
  ZarSettlementStatus status = ZarSettlementStatus.completed,
  DateTime? completedAt,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: direction,
  amount: amount,
  scheduledAt: _at,
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed
      ? completedAt ?? _at
      : null,
  createdBy: 'test',
  createdAt: _at,
  updatedAt: _at,
);

ZarCurrencyAssetAmount _money(String code, int amount) =>
    ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: code, minorUnits: amount, minorUnitScale: 0),
    );

void main() {
  const projector = ZarCustomerOperationalBalanceProjector();

  ZarCustomerOperationalBalance project({
    Iterable<ZarDeal> deals = const [],
    Iterable<ZarSettlement> settlements = const [],
  }) => projector.project(
    personId: 'person',
    deals: deals,
    settlements: settlements,
    allocations: const <ZarPaymentAllocation>[],
  );

  test('buy and sell priced deals create opposite Toman positions', () {
    final buy = project(deals: [_deal(type: ZarDealType.buy, totalToman: 500)]);
    expect(buy.payableToman, BigInt.from(500));
    expect(buy.receivableToman, BigInt.zero);

    final sell = project(
      deals: [_deal(type: ZarDealType.sell, totalToman: 500)],
    );
    expect(sell.receivableToman, BigInt.from(500));
    expect(sell.payableToman, BigInt.zero);
  });

  test(
    'completed receive reduces receivable and over-receipt flips direction',
    () {
      final partial = project(
        deals: [_deal(type: ZarDealType.sell, totalToman: 2000)],
        settlements: [
          _settlement(
            direction: ZarSettlementDirection.receive,
            amount: _money('TOMAN', 500),
          ),
        ],
      );
      expect(partial.receivableToman, BigInt.from(1500));
      expect(partial.payableToman, BigInt.zero);

      final over = project(
        deals: [_deal(type: ZarDealType.sell, totalToman: 1000)],
        settlements: [
          _settlement(
            direction: ZarSettlementDirection.receive,
            amount: _money('TOMAN', 1500),
          ),
        ],
      );
      expect(over.receivableToman, BigInt.zero);
      expect(over.payableToman, BigInt.from(500));
    },
  );

  test(
    'completed deliver reduces payable and over-payment flips direction',
    () {
      final partial = project(
        deals: [_deal(type: ZarDealType.buy, totalToman: 2000)],
        settlements: [
          _settlement(
            direction: ZarSettlementDirection.deliver,
            amount: _money('TOMAN', 500),
          ),
        ],
      );
      expect(partial.payableToman, BigInt.from(1500));

      final over = project(
        deals: [_deal(type: ZarDealType.buy, totalToman: 1000)],
        settlements: [
          _settlement(
            direction: ZarSettlementDirection.deliver,
            amount: _money('TOMAN', 1500),
          ),
        ],
      );
      expect(over.payableToman, BigInt.zero);
      expect(over.receivableToman, BigInt.from(500));
    },
  );

  test('pending and cancelled movements do not change current position', () {
    final value = project(
      deals: [_deal(type: ZarDealType.sell, totalToman: 1000)],
      settlements: [
        _settlement(
          id: 'open',
          direction: ZarSettlementDirection.receive,
          amount: _money('TOMAN', 700),
          status: ZarSettlementStatus.open,
        ),
        _settlement(
          id: 'cancelled',
          direction: ZarSettlementDirection.receive,
          amount: _money('TOMAN', 700),
          status: ZarSettlementStatus.cancelled,
        ),
      ],
    );
    expect(value.receivableToman, BigInt.from(1000));
  });

  test('only identical asset identities net, with exact decimal amounts', () {
    final value = project(
      settlements: [
        _settlement(
          id: 'usd-in',
          direction: ZarSettlementDirection.receive,
          amount: ZarCurrencyAssetAmount(
            ZarCurrencyAmount(
              code: 'USD',
              minorUnits: 10005,
              minorUnitScale: 2,
            ),
          ),
        ),
        _settlement(
          id: 'usd-out',
          direction: ZarSettlementDirection.deliver,
          amount: ZarCurrencyAssetAmount(
            ZarCurrencyAmount(code: 'USD', minorUnits: 1000, minorUnitScale: 2),
          ),
        ),
        _settlement(
          id: 'eur-out',
          direction: ZarSettlementDirection.deliver,
          amount: _money('EUR', 20),
        ),
        _settlement(
          id: 'gold750',
          direction: ZarSettlementDirection.receive,
          amount: ZarGoldAssetAmount(
            ZarGoldQuantity(decimal: '10.25', purity: '750'),
          ),
        ),
        _settlement(
          id: 'gold995',
          direction: ZarSettlementDirection.receive,
          amount: ZarGoldAssetAmount(
            ZarGoldQuantity(decimal: '2', purity: '995'),
          ),
        ),
      ],
    );
    final usd = value.payableAssetBuckets.firstWhere(
      (bucket) => bucket.currencyCode == 'USD',
    );
    expect(usd.amount, '90.05');
    expect(
      value.receivableAssetBuckets.any(
        (bucket) => bucket.currencyCode == 'EUR',
      ),
      isTrue,
    );
    expect(
      value.payableAssetBuckets.any((bucket) => bucket.goldFineness == '750'),
      isTrue,
    );
    expect(
      value.payableAssetBuckets.any((bucket) => bucket.goldFineness == '995'),
      isTrue,
    );
  });

  test(
    'coin lines retain exact variant identity and running statement is traceable',
    () {
      ZarCoinBundleAmount bundle(String id, int quantity) =>
          ZarCoinBundleAmount([
            ZarCoinLine(
              id: '$id-line',
              coinTypeId: id,
              coinTypeNameSnapshot: id == 'imam' ? 'سکه امامی' : 'پارسیان',
              quantity: quantity,
              weightPerPieceGrams: id == 'parsian' ? '0.5' : null,
              fineness: id == 'parsian' ? '750' : null,
            ),
          ]);
      final value = const ZarCustomerLedgerProjector().project(
        personId: 'person',
        deals: const [],
        settlements: [
          _settlement(
            id: 'imam-in',
            direction: ZarSettlementDirection.receive,
            amount: bundle('imam', 3),
          ),
          _settlement(
            id: 'parsian-out',
            direction: ZarSettlementDirection.deliver,
            amount: bundle('parsian', 2),
          ),
        ],
      );
      expect(value.payableAssetBuckets.single.displayName, 'سکه امامی');
      expect(value.payableAssetBuckets.single.amount, '3');
      expect(
        value.receivableAssetBuckets.single.displayName,
        contains('پارسیان'),
      );
      final lines = value.statementFor('coin:imam||');
      expect(lines, hasLength(1));
      expect(lines.single.posting.sourceRecordId, 'imam-in');
      expect(lines.single.runningAmount, '3');
    },
  );

  test('old unpriced deals create no invented customer amount', () {
    final deal = ZarDeal(
      id: 'legacy',
      businessId: 'business',
      type: ZarDealType.buy,
      personId: 'person',
      amount: _money('USD', 10),
      dealAt: _at,
      createdBy: 'test',
      createdAt: _at,
      updatedAt: _at,
    );
    final value = project(deals: [deal]);
    expect(value.receivableAssetBuckets, isEmpty);
    expect(value.payableAssetBuckets, isEmpty);
  });

  test(
    'each net bucket exposes a stable key and reconcilable running lines',
    () {
      final deal = _deal(type: ZarDealType.sell, totalToman: 2000, id: 'sell');
      final settlement = _settlement(
        id: 'receive',
        direction: ZarSettlementDirection.receive,
        amount: _money('TOMAN', 500),
      );
      final ledger = const ZarCustomerLedgerProjector().project(
        personId: 'person',
        deals: [deal],
        settlements: [settlement],
      );
      final bucket = ledger.receivableAssetBuckets.single;
      expect(bucket.assetKey, 'currency:TOMAN');
      final lines = ledger.statementFor(bucket.assetKey);
      expect(lines, hasLength(2));
      expect(lines.last.runningDirection, ZarSettlementDirection.receive);
      expect(lines.last.runningAmount, '1500');
      expect(ledger.linesForSource('sell'), hasLength(1));
      expect(ledger.linesForSource('receive'), hasLength(1));
    },
  );

  test(
    'deal accounting status is derived only from linked completed movements',
    () {
      final projector = const ZarCustomerLedgerProjector();
      final deal = _deal(
        type: ZarDealType.buy,
        totalToman: 2000,
        id: 'deal-status',
      );
      expect(
        projector.accountingStatusForDeal(deal: deal, settlements: const []),
        ZarCustomerDealAccountingStatus.unsettled,
      );
      final base = _settlement(
        id: 'linked',
        direction: ZarSettlementDirection.deliver,
        amount: _money('TOMAN', 500),
      );
      final linked = ZarSettlement(
        id: base.id,
        businessId: base.businessId,
        dealId: deal.id,
        personId: base.personId,
        direction: base.direction,
        amount: base.amount,
        scheduledAt: base.scheduledAt,
        hasTime: base.hasTime,
        status: base.status,
        completedAt: base.completedAt,
        createdBy: base.createdBy,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      );
      expect(
        projector.accountingStatusForDeal(deal: deal, settlements: [linked]),
        ZarCustomerDealAccountingStatus.partiallySettled,
      );
    },
  );
}
