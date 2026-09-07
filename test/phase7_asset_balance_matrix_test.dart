import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/application/operational_inventory_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7);
  final line = ZarCoinLine(id: 'line', coinTypeId: 'emami', coinTypeNameSnapshot: 'امامی', quantity: 3);
  final cases = <String, (ZarAssetAmount, ZarDealPricing, int)>{
    'gold': (ZarGoldAssetAmount(ZarGoldQuantity(decimal: '100', unit: ZarGoldUnit.gram, purity: '750')),
      ZarGoldDealPricing.calculate(fineness: '750', inputWeight: '100', inputWeightUnit: ZarGoldUnit.gram,
        priceUnit: ZarGoldUnit.gram, pricePerUnitToman: ZarTomanAmount(5000000)), 500000000),
    'USD': (ZarCurrencyAssetAmount(ZarCurrencyAmount(code: 'USD', minorUnits: 10000, minorUnitScale: 0)),
      ZarCurrencyDealPricing.calculate(amount: '10000', tomanPerUnit: '200000'), 2000000000),
    'coin': (ZarCoinBundleAmount([line]), ZarCoinDealPricing(lines: [ZarCoinLinePricing.calculate(
      line: line, method: ZarCoinPricingMethod.perPiece, unitPriceToman: ZarTomanAmount(40000000))]), 120000000),
  };
  for (final entry in cases.entries) {
    for (final type in ZarDealType.values) {
      test('${entry.key} ${type.name}: only Toman consideration enters customer balance; asset enters inventory', () {
        final deal = ZarDeal(id: 'd', businessId: 'b', personId: 'p', type: type,
          amount: entry.value.$1, pricing: entry.value.$2, dealAt: now, createdAt: now, updatedAt: now, createdBy: 'u');
        final balance = const ZarCustomerOperationalBalanceProjector().project(personId: 'p', deals: [deal], settlements: [], allocations: []);
        expect(type == ZarDealType.buy ? balance.payableToman : balance.receivableToman, BigInt.from(entry.value.$3));
        expect(type == ZarDealType.buy ? balance.receivableToman : balance.payableToman, BigInt.zero);
        final inventory = const ZarOperationalInventoryProjector().project(deals: [deal], settlements: []);
        final sign = type == ZarDealType.buy ? '' : '-';
        if (entry.key == 'gold') expect(inventory.goldInventory.single.grams, '${sign}100');
        if (entry.key == 'USD') expect(inventory.currencyInventory.single.decimalAmount, '${sign}10000');
        if (entry.key == 'coin') expect(inventory.coinInventory.single.quantity, type == ZarDealType.buy ? 3 : -3);
        expect(inventory.pendingReceive, isEmpty);
        expect(inventory.pendingDeliver, isEmpty);
      });
    }
  }
}
