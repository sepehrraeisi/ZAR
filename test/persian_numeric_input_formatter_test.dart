import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/editors/persian_numeric_input_formatter.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  TextEditingValue value(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  test('Persian and Latin money is grouped without precision loss', () {
    const formatter = PersianNumericInputFormatter();
    for (final input in ['50000000.125', '۵۰۰۰۰۰۰۰٫۱۲۵']) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value(input),
      );
      expect(result.text, '۵۰٬۰۰۰٬۰۰۰٫۱۲۵');
      expect(normalizeDecimal(result.text), '50000000.125');
      expect(result.selection.baseOffset, result.text.length);
    }
  });
  test('weight and decimal fineness remain exact without grouping', () {
    const formatter = PersianNumericInputFormatter(group: false);
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, value('4.6083')).text,
      '۴٫۶۰۸۳',
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, value('999.9')).text,
      '۹۹۹٫۹',
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, value('1234.')).text,
      '۱۲۳۴٫',
    );
  });
  test(
    'integer fields reject decimals; invalid paste preserves previous value',
    () {
      const formatter = PersianNumericInputFormatter(decimal: false);
      expect(formatter.formatEditUpdate(value('۳'), value('3.5')).text, '۳');
      expect(formatter.formatEditUpdate(value('۳'), value('USD3')).text, '۳');
    },
  );
  test('mid-field cursor and selection are preserved', () {
    const formatter = PersianNumericInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '12345',
        selection: TextSelection(baseOffset: 2, extentOffset: 4),
      ),
    );
    expect(result.text, '۱۲٬۳۴۵');
    expect(
      result.selection,
      const TextSelection(baseOffset: 2, extentOffset: 5),
    );
    expect(formatter.formatEditUpdate(result, value('')).text, '');
  });
}
