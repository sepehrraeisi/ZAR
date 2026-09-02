import 'package:flutter_app/application/operational_inventory_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = ZarOperationalInventoryProjector();

  test('currency buy immediately increases operational position', () {
    final result = projector.project(
      deals: [deal('buy-usd', ZarDealType.buy, currency('USD', 1000000, 2))],
      settlements: const [],
    );

    expect(result.currencyInventory.single.code, 'USD');
    expect(result.currencyInventory.single.decimalAmount, '10000');
    expect(result.currencyInventory.single.movements.single.dealType, ZarDealType.buy);
  });

  test('currency sell decreases operational position', () {
    final result = projector.project(
      deals: [
        deal('buy-usd', ZarDealType.buy, currency('USD', 1000000, 2)),
        deal('sell-usd', ZarDealType.sell, currency('USD', 250000, 2)),
      ],
      settlements: const [],
    );

    expect(result.currencyInventory.single.decimalAmount, '7500');
  });

  test('linked completed settlement does not double count its deal', () {
    final purchased = deal(
      'buy-usd',
      ZarDealType.buy,
      currency('USD', 1000000, 2),
    );
    final result = projector.project(
      deals: [purchased],
      settlements: [
        settlement(
          'receive-usd',
          dealId: purchased.id,
          direction: ZarSettlementDirection.receive,
          amount: purchased.amount,
          status: ZarSettlementStatus.completed,
        ),
      ],
    );

    expect(result.currencyInventory.single.decimalAmount, '10000');
  });

  test('standalone completed receive still increases inventory', () {
    final result = projector.project(
      settlements: [
        settlement(
          'receive-usd',
          direction: ZarSettlementDirection.receive,
          amount: currency('USD', 500000, 2),
          status: ZarSettlementStatus.completed,
        ),
      ],
    );

    expect(result.currencyInventory.single.decimalAmount, '5000');
  });

  test('cancelled deal does not affect inventory', () {
    final result = projector.project(
      deals: [
        deal(
          'cancelled',
          ZarDealType.buy,
          currency('USD', 1000000, 2),
          status: ZarDealStatus.cancelled,
        ),
      ],
      settlements: const [],
    );

    expect(result.currencyInventory, isEmpty);
  });
}

final _time = DateTime.utc(2026, 9, 2, 12);

ZarDeal deal(
  String id,
  ZarDealType type,
  ZarAssetAmount amount, {
  ZarDealStatus status = ZarDealStatus.active,
}) => ZarDeal(
  id: id,
  businessId: 'business',
  type: type,
  personId: 'person',
  amount: amount,
  dealAt: _time,
  status: status,
  createdBy: 'user',
  createdAt: _time,
  updatedAt: _time,
);

ZarSettlement settlement(
  String id, {
  String? dealId,
  required ZarSettlementDirection direction,
  required ZarAssetAmount amount,
  ZarSettlementStatus status = ZarSettlementStatus.open,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  dealId: dealId,
  personId: 'person',
  direction: direction,
  amount: amount,
  scheduledAt: _time,
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed ? _time : null,
  completedBy: status == ZarSettlementStatus.completed ? 'user' : null,
  createdBy: 'user',
  createdAt: _time,
  updatedAt: _time,
);

ZarCurrencyAssetAmount currency(String code, int units, int scale) =>
    ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: code, minorUnits: units, minorUnitScale: scale),
    );
