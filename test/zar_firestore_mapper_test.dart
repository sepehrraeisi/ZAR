import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/firestore/zar_firestore_mapper.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  const mapper = ZarFirestoreMapper();

  test('person mapping normalizes searchable Persian name', () {
    final person = ZarPerson(
      id: 'p1',
      displayName: '  علي   رضايي  ',
      phone: '09121234567',
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 8, 27),
      createdBy: 'u1',
    );
    final map = mapper.personToMap(person);
    expect(map['normalizedName'], 'علی رضایی');
  });

  test('currency settlement Firestore roundtrip keeps exact minor units', () {
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'p1',
      direction: ZarSettlementDirection.deliver,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1000000),
      ),
      scheduledAt: DateTime(2026, 8, 27, 11, 30),
      hasTime: true,
      createdBy: 'u1',
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 8, 27),
    );

    final map = mapper.settlementToMap(settlement);
    final restored = mapper.settlementFromMap(
      id: settlement.id,
      businessId: settlement.businessId,
      map: map,
    );

    final amount = restored.amount as ZarCurrencyAssetAmount;
    expect(amount.value.code, 'USD');
    expect(amount.value.minorUnits, 1000000);
    expect(restored.direction, ZarSettlementDirection.deliver);
  });

  test('gold deal Firestore roundtrip preserves decimal string', () {
    final deal = ZarDeal(
      id: 'd1',
      businessId: 'b1',
      type: ZarDealType.buy,
      personId: 'p1',
      amount: ZarGoldAssetAmount(
        ZarGoldQuantity(decimal: '1000.125', purity: '750'),
      ),
      pricing: ZarGoldDealPricing(
        fineness: 750,
        pricePerGramToman: ZarTomanAmount(4900000),
        totalToman: ZarTomanAmount(4900612500),
      ),
      dealAt: DateTime(2026, 8, 27, 9),
      createdBy: 'u1',
      createdAt: DateTime(2026, 8, 27, 9),
      updatedAt: DateTime(2026, 8, 27, 9),
    );

    final restored = mapper.dealFromMap(
      id: deal.id,
      businessId: deal.businessId,
      map: mapper.dealToMap(deal),
    );
    final amount = restored.amount as ZarGoldAssetAmount;
    expect(amount.value.decimal, '1000.125');
    expect(amount.value.purity, '750');
    final pricing = restored.pricing as ZarGoldDealPricing;
    expect(pricing.pricePerGramToman.wholeTomans, 4900000);
    expect(pricing.totalToman.wholeTomans, 4900612500);
  });
}
