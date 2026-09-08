import 'zar_domain_models.dart';

const Map<String, int> zarCurrencyMinorUnitScales = {
  'USD': 2,
  'EUR': 2,
  'AED': 2,
  'TRY': 2,
  'GBP': 2,
  'CAD': 2,
};

ZarCurrencyAmount parseCurrencyAmount({
  required String code,
  required String input,
}) {
  final normalizedCode = code.trim().toUpperCase();
  final scale = zarCurrencyMinorUnitScales[normalizedCode] ?? 2;
  final normalized = normalizeNumericInput(input);
  final parts = normalized.split('.');
  final whole = parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';

  if (fraction.length > scale) {
    throw FormatException(
      '$normalizedCode supports at most $scale decimal places in ZAR+.',
    );
  }

  final paddedFraction = fraction.padRight(scale, '0');
  final factor = _pow10(scale);
  final wholeValue = int.parse(whole);
  final fractionValue = paddedFraction.isEmpty ? 0 : int.parse(paddedFraction);
  final minorUnits = wholeValue * factor + fractionValue;

  return ZarCurrencyAmount(
    code: normalizedCode,
    minorUnits: minorUnits,
    minorUnitScale: scale,
  );
}

ZarGoldQuantity parseGoldQuantity({
  required String input,
  ZarGoldUnit unit = ZarGoldUnit.gram,
  String? purity,
}) =>
    ZarGoldQuantity(
      decimal: normalizeNumericInput(input),
      unit: unit,
      purity: purity,
    );

String normalizeNumericInput(String input) {
  final value = input
      .trim()
      .replaceAll('۰', '0')
      .replaceAll('۱', '1')
      .replaceAll('۲', '2')
      .replaceAll('۳', '3')
      .replaceAll('۴', '4')
      .replaceAll('۵', '5')
      .replaceAll('۶', '6')
      .replaceAll('۷', '7')
      .replaceAll('۸', '8')
      .replaceAll('۹', '9')
      .replaceAll('٫', '.')
      .replaceAll(',', '')
      .replaceAll('٬', '');

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Invalid numeric value.');
  }
  return value;
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}
