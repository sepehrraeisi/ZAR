import 'zar_domain_models.dart';

/// Exact parser for user-entered currency amounts.
///
/// It accepts Persian/Arabic/Latin digits, common grouping separators and
/// either `.` or the Persian decimal separator `٫`. It never converts through
/// `double`, so values such as 0.1 remain exact.
class ZarAmountParser {
  const ZarAmountParser._();

  static const Map<String, int> defaultCurrencyScales = {
    'USD': 2,
    'EUR': 2,
    'AED': 2,
    'TRY': 2,
    'GBP': 2,
    'CAD': 2,
  };

  static ZarCurrencyAmount currency(
    String input, {
    required String code,
    int? minorUnitScale,
  }) {
    final normalizedCode = code.trim().toUpperCase();
    final scale = minorUnitScale ?? defaultCurrencyScales[normalizedCode] ?? 2;
    if (scale < 0 || scale > 6) {
      throw const FormatException('Unsupported currency minor-unit scale.');
    }

    final normalized = _normalizeNumericInput(input);
    final parts = normalized.split('.');
    final whole = parts[0];
    final rawFraction = parts.length == 2 ? parts[1] : '';

    if (rawFraction.length > scale) {
      final excess = rawFraction.substring(scale);
      if (RegExp(r'[1-9]').hasMatch(excess)) {
        throw FormatException(
          '$normalizedCode supports at most $scale decimal places.',
        );
      }
    }

    final fraction = scale == 0
        ? ''
        : rawFraction.padRight(scale, '0').substring(0, scale);
    final minorDigits = '$whole$fraction'.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final minorUnits = int.parse(minorDigits.isEmpty ? '0' : minorDigits);

    return ZarCurrencyAmount(
      code: normalizedCode,
      minorUnits: minorUnits,
      minorUnitScale: scale,
    );
  }

  static ZarGoldQuantity gold(
    String input, {
    ZarGoldUnit unit = ZarGoldUnit.gram,
    String? purity,
  }) {
    return ZarGoldQuantity(
      decimal: _normalizeNumericInput(input),
      unit: unit,
      purity: purity,
    );
  }

  static String _normalizeNumericInput(String input) {
    final value = _latinDigits(input.trim())
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll(' ', '')
        .replaceAll('٫', '.');

    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      throw const FormatException('Invalid numeric amount.');
    }

    final parts = value.split('.');
    final integer = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (parts.length == 1) return integer;
    return '$integer.${parts[1]}';
  }

  static String _latinDigits(String input) {
    const source = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
    const target = '01234567890123456789';
    var result = input;
    for (var i = 0; i < source.length; i++) {
      result = result.replaceAll(source[i], target[i]);
    }
    return result;
  }
}
