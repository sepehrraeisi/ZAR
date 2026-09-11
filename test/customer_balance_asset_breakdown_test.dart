import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 9, 11, 12);

ZarSettlement _settlement(
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

void main() {
  const projector = ZarCustomerOperationalBalanceProjector();

  test('groups open balances by currency and gold fineness', () {
    final value = projector.project(
      personId: 'person',
      deals: const [],
      settlements: [
        _settlement(
          'usd',
          ZarSettlementDirection.receive,
          ZarCurrencyAssetAmount(
            ZarCurrencyAmount(
              code: 'USD',
              minorUnits: 10000,
              minorUnitScale: 0,
            ),
          ),
        ),
        _settlement(
          'eur',
          ZarSettlementDirection.receive,
          ZarCurrencyAssetAmount(
            ZarCurrencyAmount(
              code: 'EUR',
              minorUnits: 45000,
              minorUnitScale: 0,
            ),
          ),
        ),
        _settlement(
          'gold-750',
          ZarSettlementDirection.receive,
          ZarGoldAssetAmount(ZarGoldQuantity(decimal: '100', purity: '750')),
        ),
        _settlement(
          'gold-740',
          ZarSettlementDirection.receive,
          ZarGoldAssetAmount(ZarGoldQuantity(decimal: '25.5', purity: '740')),
        ),
      ],
      allocations: const <ZarPaymentAllocation>[],
    );

    expect(
      value.receivableAssetBuckets.map((item) => item.currencyCode),
      containsAll(<String?>['USD', 'EUR']),
    );
    expect(
      value.receivableAssetBuckets.map((item) => item.goldFineness),
      containsAll(<String?>['750', '740']),
    );
    expect(value.receivableAssetBuckets, hasLength(4));
  });

  test(
    'keeps coin variants separate and completed settlements out of balance',
    () {
      final imam = ZarCoinLine(
        id: 'line-1',
        coinTypeId: 'imam',
        coinTypeNameSnapshot: 'سکه امامی',
        quantity: 2,
      );
      final quarter = ZarCoinLine(
        id: 'line-2',
        coinTypeId: 'quarter',
        coinTypeNameSnapshot: 'ربع‌سکه',
        quantity: 3,
        weightPerPieceGrams: '0.5',
        fineness: '750',
      );
      final completed = ZarSettlement(
        id: 'completed',
        businessId: 'business',
        personId: 'person',
        direction: ZarSettlementDirection.receive,
        amount: ZarCoinBundleAmount([imam]),
        scheduledAt: _at,
        hasTime: true,
        status: ZarSettlementStatus.completed,
        completedAt: _at,
        createdBy: 'user',
        createdAt: _at,
        updatedAt: _at,
      );
      final value = projector.project(
        personId: 'person',
        deals: const [],
        settlements: [
          completed,
          _settlement(
            'open-coins',
            ZarSettlementDirection.deliver,
            ZarCoinBundleAmount([quarter]),
          ),
        ],
        allocations: const <ZarPaymentAllocation>[],
      );

      expect(value.receivableAssetBuckets, isEmpty);
      expect(value.payableAssetBuckets.single.displayName, contains('ربع‌سکه'));
      expect(value.payableAssetBuckets.single.amount, '3');
    },
  );
}
