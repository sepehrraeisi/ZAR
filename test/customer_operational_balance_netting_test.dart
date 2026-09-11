import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 9, 11, 12);

ZarSettlement _openSettlement(
  String id,
  ZarSettlementDirection direction,
  ZarAssetAmount amount,
) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: direction,
  amount: amount,
  scheduledAt: _at,
  hasTime: true,
  status: ZarSettlementStatus.open,
  createdBy: 'user',
  createdAt: _at,
  updatedAt: _at,
);

ZarCurrencyAssetAmount _currency(String code, int amount) =>
    ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: code, minorUnits: amount, minorUnitScale: 0),
    );

void main() {
  const projector = ZarCustomerOperationalBalanceProjector();

  ZarCustomerOperationalBalance project(List<ZarSettlement> settlements) =>
      projector.project(
        personId: 'person',
        deals: const [],
        settlements: settlements,
        allocations: const <ZarPaymentAllocation>[],
      );

  test('nets identical Toman buckets and leaves gross obligations intact', () {
    final balance = project([
      _openSettlement(
        'receive',
        ZarSettlementDirection.receive,
        _currency('TOMAN', 700000000),
      ),
      _openSettlement(
        'deliver',
        ZarSettlementDirection.deliver,
        _currency('TOMAN', 350000000),
      ),
    ]);

    expect(balance.obligations, hasLength(2));
    expect(balance.receivableToman, BigInt.from(350000000));
    expect(balance.payableToman, BigInt.zero);
    expect(balance.receivableAssetBuckets, hasLength(1));
    expect(balance.receivableAssetBuckets.single.amount, '350000000');
    expect(balance.payableAssetBuckets, isEmpty);
  });

  test('shows the payable side when it is larger', () {
    final balance = project([
      _openSettlement(
        'receive',
        ZarSettlementDirection.receive,
        _currency('TOMAN', 200000000),
      ),
      _openSettlement(
        'deliver',
        ZarSettlementDirection.deliver,
        _currency('TOMAN', 500000000),
      ),
    ]);

    expect(balance.receivableAssetBuckets, isEmpty);
    expect(balance.payableToman, BigInt.from(300000000));
    expect(balance.payableAssetBuckets.single.amount, '300000000');
  });

  test('does not net different currencies and removes exact zero', () {
    final balance = project([
      _openSettlement(
        'usd-in',
        ZarSettlementDirection.receive,
        _currency('USD', 5000),
      ),
      _openSettlement(
        'usd-out',
        ZarSettlementDirection.deliver,
        _currency('USD', 5000),
      ),
      _openSettlement(
        'usd-more',
        ZarSettlementDirection.receive,
        _currency('USD', 10000),
      ),
      _openSettlement(
        'eur-out',
        ZarSettlementDirection.deliver,
        _currency('EUR', 3000),
      ),
    ]);

    expect(balance.receivableAssetBuckets.single.currencyCode, 'USD');
    expect(balance.receivableAssetBuckets.single.amount, '10000');
    expect(balance.payableAssetBuckets.single.currencyCode, 'EUR');
    expect(balance.payableAssetBuckets.single.amount, '3000');
  });

  test('nets only gold with the same purity, including unknown purity', () {
    final balance = project([
      _openSettlement(
        'gold-in',
        ZarSettlementDirection.receive,
        ZarGoldAssetAmount(ZarGoldQuantity(decimal: '100.50', purity: '750')),
      ),
      _openSettlement(
        'gold-out',
        ZarSettlementDirection.deliver,
        ZarGoldAssetAmount(ZarGoldQuantity(decimal: '40.25', purity: '750')),
      ),
      _openSettlement(
        'gold-740',
        ZarSettlementDirection.deliver,
        ZarGoldAssetAmount(ZarGoldQuantity(decimal: '10', purity: '740')),
      ),
      _openSettlement(
        'gold-unknown-in',
        ZarSettlementDirection.receive,
        ZarGoldAssetAmount(ZarGoldQuantity(decimal: '8')),
      ),
      _openSettlement(
        'gold-unknown-out',
        ZarSettlementDirection.deliver,
        ZarGoldAssetAmount(ZarGoldQuantity(decimal: '3.5')),
      ),
    ]);

    final gold750 = balance.receivableAssetBuckets.firstWhere(
      (bucket) => bucket.goldFineness == '750',
    );
    final unknown = balance.receivableAssetBuckets.firstWhere(
      (bucket) => bucket.goldFineness == null,
    );
    expect(gold750.amount, '60.25');
    expect(unknown.amount, '4.5');
    expect(balance.payableAssetBuckets.single.goldFineness, '740');
    expect(balance.payableAssetBuckets.single.amount, '10');
  });

  test('nets exact coin identity but keeps variants separate', () {
    ZarCoinBundleAmount bundle(
      String typeId,
      String name,
      int quantity, {
      String? weight,
      String? fineness,
    }) => ZarCoinBundleAmount([
      ZarCoinLine(
        id: '$typeId-line',
        coinTypeId: typeId,
        coinTypeNameSnapshot: name,
        quantity: quantity,
        weightPerPieceGrams: weight,
        fineness: fineness,
      ),
    ]);

    final balance = project([
      _openSettlement(
        'coin-in',
        ZarSettlementDirection.receive,
        bundle('quarter', 'ربع‌سکه', 25, weight: '0.5', fineness: '750'),
      ),
      _openSettlement(
        'coin-out',
        ZarSettlementDirection.deliver,
        bundle('quarter', 'ربع‌سکه', 5, weight: '0.5', fineness: '750'),
      ),
      _openSettlement(
        'coin-other',
        ZarSettlementDirection.deliver,
        bundle('imam', 'سکه امامی', 2),
      ),
    ]);

    expect(balance.receivableAssetBuckets.single.amount, '20');
    expect(
      balance.receivableAssetBuckets.single.displayName,
      startsWith('ربع‌سکه'),
    );
    expect(balance.payableAssetBuckets.single.amount, '2');
    expect(
      balance.payableAssetBuckets.single.displayName,
      startsWith('سکه امامی'),
    );
  });
}
