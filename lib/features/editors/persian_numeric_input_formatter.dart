import 'package:flutter/services.dart';

/// Presentation-only formatting. No floating point conversion or rounding.
class PersianNumericInputFormatter extends TextInputFormatter {
  const PersianNumericInputFormatter({this.decimal = true, this.group = true});

  final bool decimal;
  final bool group;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    String canonical(String text) {
      const persian = '۰۱۲۳۴۵۶۷۸۹';
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      for (var i = 0; i < 10; i++) {
        text = text.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
      }
      return text.replaceAll('٬', '').replaceAll(',', '').replaceAll('٫', '.');
    }

    final raw = canonical(newValue.text);
    if (!(decimal ? RegExp(r'^\d*(\.\d*)?$') : RegExp(r'^\d*$')).hasMatch(
      raw,
    )) {
      return oldValue;
    }
    final parts = raw.split('.');
    var integer = parts.first;
    if (group) {
      integer = integer.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]}٬',
      );
    }
    var formatted = integer + (parts.length == 2 ? '٫${parts[1]}' : '');
    for (var i = 0; i < 10; i++) {
      formatted = formatted.replaceAll('$i', '۰۱۲۳۴۵۶۷۸۹'[i]);
    }
    int offset(int original) {
      if (original < 0) return formatted.length;
      final count = canonical(
        newValue.text.substring(0, original.clamp(0, newValue.text.length)),
      ).length;
      if (count == 0) return 0;
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != '٬') seen++;
        if (seen == count) return i + 1;
      }
      return formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
