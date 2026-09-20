import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_test/flutter_test.dart';

final at = DateTime.utc(2026, 9, 5);
ZarCurrencyAssetAmount money(String code, int amount) => ZarCurrencyAssetAmount(
  ZarCurrencyAmount(code: code, minorUnits: amount, minorUnitScale: 0),
);
ZarDeal deal(ZarDealType type, {bool priced = true}) => ZarDeal(
  id: 'deal',
  businessId: 'b',
  personId: 'p',
  type: type,
  amount: money('USD', 10000),
  pricing: priced
      ? ZarCurrencyDealPricing.calculate(
          amount: '10000',
          tomanPerUnit: '200000',
        )
      : null,
  dealAt: at,
  createdBy: 'u',
  createdAt: at,
  updatedAt: at,
);
ZarSettlement payment(
  ZarSettlementDirection direction, {
  ZarSettlementStatus status = ZarSettlementStatus.completed,
  String person = 'p',
}) => ZarSettlement(
  id: 'payment',
  businessId: 'b',
  personId: person,
  direction: direction,
  amount: money('TOMAN', 500000000),
  scheduledAt: at,
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed ? at : null,
  createdBy: 'u',
  createdAt: at,
  updatedAt: at,
);
ZarPaymentAllocation allocation({int amount = 500000000}) =>
    ZarPaymentAllocation(
      settlementId: 'payment',
      targetType: ZarPaymentAllocationTarget.deal,
      targetId: 'deal',
      amount: ZarTomanAmount(amount),
    );

void main() {
  const projector = ZarCustomerOperationalBalanceProjector();
  test(
    'scheduled allocation does not duplicate or prematurely discharge deal',
    () {
      final result = projector.project(
        personId: 'p',
        deals: [deal(ZarDealType.sell)],
        settlements: [
          payment(
            ZarSettlementDirection.receive,
            status: ZarSettlementStatus.open,
          ),
        ],
        allocations: [allocation()],
      );
      expect(result.receivableToman, BigInt.from(2000000000));
    },
  );
  test('open cash obligation does not affect current balance', () {
    final result = projector.project(
      personId: 'p',
      deals: [deal(ZarDealType.sell)],
      settlements: [
        payment(
          ZarSettlementDirection.receive,
          status: ZarSettlementStatus.open,
        ),
      ],
      allocations: [],
    );
    expect(result.receivableToman, BigInt.from(2000000000));
  });
  for (final type in ZarDealType.values) {
    final direction = type == ZarDealType.buy
        ? ZarSettlementDirection.deliver
        : ZarSettlementDirection.receive;
    BigInt remaining(ZarCustomerOperationalBalance value) =>
        type == ZarDealType.buy ? value.payableToman : value.receivableToman;
    test(
      '${type.name}: completed movement reduces balance once, allocation does not double subtract',
      () {
        final source = payment(direction);
        final free = projector.project(
          personId: 'p',
          deals: [deal(type)],
          settlements: [source],
          allocations: [],
        );
        expect(remaining(free), BigInt.from(1500000000));
        for (var repeat = 0; repeat < 3; repeat++) {
          final allocated = projector.project(
            personId: 'p',
            deals: [deal(type)],
            settlements: [source],
            allocations: [allocation()],
          );
          expect(remaining(allocated), BigInt.from(1500000000));
        }
      },
    );
    test('${type.name}: cancelled allocation source has no current effect', () {
      final value = projector.project(
        personId: 'p',
        deals: [deal(type)],
        settlements: [
          payment(direction, status: ZarSettlementStatus.cancelled),
        ],
        allocations: [allocation()],
      );
      expect(remaining(value), BigInt.from(2000000000));
    });
  }
  test('legacy unpriced deal creates no financial amount', () {
    final value = projector.project(
      personId: 'p',
      deals: [deal(ZarDealType.buy, priced: false)],
      settlements: [],
      allocations: [],
    );
    expect(value.obligations, isEmpty);
  });
  test('duplicate allocation is rejected instead of subtracting twice', () {
    expect(
      () => projector.project(
        personId: 'p',
        deals: [deal(ZarDealType.sell)],
        settlements: [payment(ZarSettlementDirection.receive)],
        allocations: [allocation(), allocation()],
      ),
      throwsFormatException,
    );
  });
  test('wrong direction and person are rejected', () {
    for (final source in [
      payment(ZarSettlementDirection.deliver),
      payment(ZarSettlementDirection.receive, person: 'other'),
    ]) {
      expect(
        () => projector.project(
          personId: 'p',
          deals: [deal(ZarDealType.sell)],
          settlements: [source],
          allocations: [allocation()],
        ),
        throwsFormatException,
      );
    }
  });
  test('cannot allocate more than source payment', () {
    expect(
      () => projector.project(
        personId: 'p',
        deals: [deal(ZarDealType.sell)],
        settlements: [payment(ZarSettlementDirection.receive)],
        allocations: [allocation(amount: 500000001)],
      ),
      throwsFormatException,
    );
  });
}
