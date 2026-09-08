import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/operational_inventory_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'customer_operational_balance_projector_test.dart' as fixtures;

void main() {
  ZarSettlement target(ZarSettlementStatus status) => ZarSettlement(
    id: 'obligation',
    businessId: 'b',
    personId: 'p',
    direction: ZarSettlementDirection.receive,
    amount: fixtures.money('TOMAN', 2000000000),
    scheduledAt: fixtures.at,
    hasTime: true,
    status: status,
    completedAt: status == ZarSettlementStatus.completed ? fixtures.at : null,
    createdBy: 'u',
    createdAt: fixtures.at,
    updatedAt: fixtures.at,
  );
  test('partial receipt plus completion moves only remaining amount once', () {
    final source = fixtures.payment(ZarSettlementDirection.receive);
    final row = ZarPaymentAllocation(
      settlementId: source.id,
      targetType: ZarPaymentAllocationTarget.settlement,
      targetId: 'obligation',
      amount: ZarTomanAmount(500000000),
    );
    const projector = ZarOperationalInventoryProjector();
    final open = projector.project(
      settlements: [source, target(ZarSettlementStatus.open)],
      allocations: [row],
    );
    expect(open.cashInventory.single.decimalAmount, '500000000');
    expect(
      (open.pendingReceive.single as ZarCurrencyInventoryItem).decimalAmount,
      '1500000000',
    );
    for (var i = 0; i < 3; i++) {
      final closed = projector.project(
        settlements: [source, target(ZarSettlementStatus.completed)],
        allocations: [row],
      );
      expect(closed.cashInventory.single.decimalAmount, '2000000000');
      expect(closed.pendingReceive, isEmpty);
    }
  });
  test(
    'cash paid for linked USD deal must not disappear from cash inventory',
    () {
      final deal = fixtures.deal(ZarDealType.buy);
      final source = ZarSettlement(
        id: 'cash',
        businessId: 'b',
        personId: 'p',
        dealId: deal.id,
        direction: ZarSettlementDirection.deliver,
        amount: fixtures.money('TOMAN', 500000000),
        scheduledAt: fixtures.at,
        hasTime: true,
        status: ZarSettlementStatus.completed,
        completedAt: fixtures.at,
        createdBy: 'u',
        createdAt: fixtures.at,
        updatedAt: fixtures.at,
      );
      final result = const ZarOperationalInventoryProjector().project(
        deals: [deal],
        settlements: [source],
      );
      expect(result.currencyInventory.single.decimalAmount, '10000');
      expect(result.cashInventory.single.decimalAmount, '-500000000');
    },
  );
}
