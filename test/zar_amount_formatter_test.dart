import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/domain/zar_amount_formatter.dart';
import 'package:flutter_app/domain/zar_amount_parser.dart';

void main() {
  test('formats exact decimals without losing cents', () {
    final usd = ZarAmountParser.currency('۱۰٬۰۰۰٫۵۰', code: 'USD');
    final eur = ZarAmountParser.currency('1234.05', code: 'EUR');

    expect(ZarAmountFormatter.currency(usd), r'$۱۰,۰۰۰.۵۰');
    expect(ZarAmountFormatter.currency(eur), '€۱,۲۳۴.۰۵');
  });

  test('formats code-based currencies cleanly', () {
    final aed = ZarAmountParser.currency('20000', code: 'AED');
    final cad = ZarAmountParser.currency('1500.25', code: 'CAD');

    expect(ZarAmountFormatter.currency(aed), 'AED ۲۰,۰۰۰');
    expect(ZarAmountFormatter.currency(cad), 'CAD ۱,۵۰۰.۲۵');
  });

  test('formats Toman as a neutral Persian amount', () {
    final toman = ZarAmountParser.currency(
      '920000000',
      code: 'TOMAN',
      minorUnitScale: 0,
    );
    expect(ZarAmountFormatter.currency(toman), '۹۲۰,۰۰۰,۰۰۰ تومان');
  });
}
