import 'package:flutter_app/domain/zar_amount_parser.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZarAmountParser.currency', () {
    test('parses Persian digits and grouping exactly', () {
      final amount = ZarAmountParser.currency('۱۰٬۰۰۰.۵۰', code: 'USD');
      expect(amount.code, 'USD');
      expect(amount.minorUnits, 1000050);
      expect(amount.minorUnitScale, 2);
    });

    test('parses Persian decimal separator', () {
      final amount = ZarAmountParser.currency('۱۲۳٫۴۵', code: 'EUR');
      expect(amount.minorUnits, 12345);
    });

    test('accepts Arabic-Indic digits', () {
      final amount = ZarAmountParser.currency('١٢٣٤٫٥٠', code: 'AED');
      expect(amount.minorUnits, 123450);
    });

    test('pads missing minor units without floating point', () {
      final amount = ZarAmountParser.currency('0.1', code: 'USD');
      expect(amount.minorUnits, 10);
    });

    test('rejects precision beyond currency scale', () {
      expect(
        () => ZarAmountParser.currency('1.001', code: 'USD'),
        throwsFormatException,
      );
    });

    test('allows extra trailing zeros beyond scale', () {
      final amount = ZarAmountParser.currency('1.2300', code: 'USD');
      expect(amount.minorUnits, 123);
    });

    test('supports explicit scale for other currencies', () {
      final amount = ZarAmountParser.currency(
        '12.345',
        code: 'OTHER',
        minorUnitScale: 3,
      );
      expect(amount.minorUnits, 12345);
      expect(amount.minorUnitScale, 3);
    });
  });

  group('ZarAmountParser.gold', () {
    test('normalizes Persian gold quantity exactly', () {
      final gold = ZarAmountParser.gold(
        '۱٬۲۵۰٫۱۲۵',
        unit: ZarGoldUnit.gram,
        purity: '18K',
      );
      expect(gold.decimal, '1250.125');
      expect(gold.purity, '18K');
    });

    test('rejects zero quantity', () {
      expect(() => ZarAmountParser.gold('۰'), throwsFormatException);
    });
  });
}
