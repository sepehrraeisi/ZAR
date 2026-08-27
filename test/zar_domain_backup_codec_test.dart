import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  const codec = ZarDomainBackupCodec();
  final created = DateTime.utc(2026, 8, 27, 12);

  test('round-trips exact gold and currency domain values', () {
    final person = ZarPerson(
      id: 'p1',
      displayName: 'علی رضایی',
      createdAt: created,
      updatedAt: created,
      createdBy: 'u1',
    );
    final deal = ZarDeal(
      id: 'd1',
      businessId: 'b1',
      type: ZarDealType.buy,
      personId: 'p1',
      amount: ZarGoldAssetAmount(
        ZarGoldQuantity(decimal: '250.125', purity: '18K'),
      ),
      dealAt: DateTime.utc(2026, 8, 27, 13),
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      dealId: 'd1',
      personId: 'p1',
      direction: ZarSettlementDirection.deliver,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: 1000050),
      ),
      scheduledAt: DateTime.utc(2026, 8, 28, 10, 30),
      hasTime: true,
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );

    final source = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: created,
      people: [person],
      deals: [deal],
      settlements: [settlement],
    );

    final decoded = codec.decodeJson(codec.encodeJson(source));

    expect(decoded.businessId, 'b1');
    final restoredGold = decoded.deals.single.amount as ZarGoldAssetAmount;
    expect(restoredGold.value.decimal, '250.125');
    expect(restoredGold.value.purity, '18K');
    final restoredCurrency =
        decoded.settlements.single.amount as ZarCurrencyAssetAmount;
    expect(restoredCurrency.value.code, 'USD');
    expect(restoredCurrency.value.minorUnits, 1000050);
  });

  test('rejects a settlement referencing an unknown person', () {
    final settlement = ZarSettlement(
      id: 's1',
      businessId: 'b1',
      personId: 'missing',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '1')),
      scheduledAt: DateTime.utc(2026, 8, 28),
      hasTime: false,
      createdBy: 'u1',
      createdAt: created,
      updatedAt: created,
    );
    final source = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: created,
      people: const [],
      deals: const [],
      settlements: [settlement],
    );

    expect(
      () => codec.decodeJson(codec.encodeJson(source)),
      throwsA(isA<FormatException>()),
    );
  });
}
