import 'zar_domain_models.dart';

/// Formats exact currency minor units without converting through `double`.
class ZarAmountFormatter {
  const ZarAmountFormatter._();

  static String currency(ZarCurrencyAmount value) {
    final scale = value.minorUnitScale;
    final raw = value.minorUnits.toString().padLeft(scale + 1, '0');
    final whole = scale == 0 ? raw : raw.substring(0, raw.length - scale);
    final fraction = scale == 0 ? '' : raw.substring(raw.length - scale);
    final groupedWhole = _group(whole);
    final visibleFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    final number = visibleFraction.isEmpty
        ? groupedWhole
        : '$groupedWhole.$visibleFraction';

    return switch (value.code) {
      'USD' => '\$$number',
      'EUR' => '€$number',
      'GBP' => '£$number',
      'TRY' => '₺$number',
      'AED' => 'AED $number',
      'CAD' => 'CAD $number',
      final code => '$code $number',
    };
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    final first = digits.length % 3;
    var index = 0;
    if (first != 0) {
      buffer.write(digits.substring(0, first));
      index = first;
    }
    while (index < digits.length) {
      if (buffer.isNotEmpty) buffer.write(',');
      buffer.write(digits.substring(index, index + 3));
      index += 3;
    }
    return buffer.toString();
  }
}
