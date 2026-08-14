import 'package:flutter/services.dart';

/// Decimal input support for locales whose numeric keyboards emit a comma
/// as the decimal separator (RO, DE, FR, ES, PT, IT, PL, SK, UK, RU...).
///
/// The old `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))` pattern
/// silently DELETED the comma, so a Romanian user typing "50,00" got a big
/// blind of 5000 (support report 2026-08-13, "minimum raise is 10000").
/// This formatter normalizes the comma to a dot instead, so the stored text
/// always parses with [double.parse].
class DecimalInputFormatter extends TextInputFormatter {
  /// Allow a leading minus sign (e.g. session profit/loss input).
  final bool signed;

  DecimalInputFormatter({this.signed = false});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // 1:1 replacement keeps length identical, so selection stays valid.
    final text = newValue.text.replaceAll(',', '.');
    final pattern = signed ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$';
    if (!RegExp(pattern).hasMatch(text)) {
      return oldValue;
    }
    return newValue.copyWith(text: text);
  }
}

/// Parse user-typed decimal text accepting both '.' and ',' separators.
/// Use this instead of `double.tryParse` for any text a user typed.
double? parseDecimal(String? text) {
  if (text == null) return null;
  return double.tryParse(text.trim().replaceAll(',', '.'));
}
