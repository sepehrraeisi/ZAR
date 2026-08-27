import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/domain/zar_amount_formatter.dart';
import 'package:flutter_app/domain/zar_amount_parser.dart';

void main() {
  test('formats exact decimals without losing cents', () {
    final usd = ZarAmountParser.currency('۱۰٬۰۰۰٫۵۰', code: 'USD');
    final eur = ZarAmountParser.currency('1234.05', code: 'EUR');

    expect(ZarAmountFormatter.currency(usd), r'$10,000.50');
    expect(ZarAmountFormatter.currency(eur), '€1,234.05');
  });

  test('formats code-based currencies cleanly', () {
    final aed = ZarAmountParser.currency('20000', code: 'AED');
    final cad = ZarAmountParser.currency('1500.25', code: 'CAD');

    expect(ZarAmountFormatter.currency(aed), 'AED 20,000');
    expect(ZarAmountFormatter.currency(cad), 'CAD 1,500.25');
  });
}
