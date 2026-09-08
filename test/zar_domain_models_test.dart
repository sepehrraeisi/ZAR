import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  group('gold decimal representation', () {
    test('normalizes Persian digits and trailing zeros exactly', () {
      final quantity = ZarGoldQuantity(decimal: '۰۰۱٬۲۵۰.۵۰۰');
      expect(quantity.decimal, '1250.5');
      expect(quantity.unit, ZarGoldUnit.gram);
    });

    test('rejects zero and invalid decimal values', () {
      expect(() => ZarGoldQuantity(decimal: '0'), throwsFormatException);
      expect(() => ZarGoldQuantity(decimal: '-1'), throwsFormatException);
      expect(() => ZarGoldQuantity(decimal: '12.3.4'), throwsFormatException);
    });
  });

  group('currency integer representation', () {
    test('normalizes currency code and preserves exact minor units', () {
      final amount = ZarCurrencyAmount(code: 'usd', minorUnits: 1000000);
      expect(amount.code, 'USD');
      expect(amount.minorUnits, 1000000);
      expect(amount.minorUnitScale, 2);
    });

    test('rejects non-positive financial values', () {
      expect(
        () => ZarCurrencyAmount(code: 'USD', minorUnits: 0),
        throwsFormatException,
      );
    });
  });

  test('asset amount map roundtrip keeps type and value', () {
    final original = ZarGoldAssetAmount(
      ZarGoldQuantity(decimal: '250.125', purity: '18K'),
    );
    final restored = ZarAssetAmount.fromMap(original.toMap());
    expect(restored, isA<ZarGoldAssetAmount>());
    expect((restored as ZarGoldAssetAmount).value.decimal, '250.125');
    expect(restored.value.purity, '18K');
  });

  test('completed settlement requires completion timestamp', () {
    final amount = ZarCurrencyAssetAmount(
      ZarCurrencyAmount(code: 'EUR', minorUnits: 500000),
    );
    expect(
      () => ZarSettlement(
        id: 's1',
        businessId: 'b1',
        personId: 'p1',
        direction: ZarSettlementDirection.deliver,
        amount: amount,
        scheduledAt: DateTime(2026, 8, 27, 11),
        hasTime: true,
        status: ZarSettlementStatus.completed,
        createdBy: 'u1',
        createdAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 27),
      ),
      throwsFormatException,
    );
  });
}
