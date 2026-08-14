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

  static final RegExp _unsigned = RegExp(r'^\d*\.?\d*$');
  static final RegExp _signed = RegExp(r'^-?\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // 1:1 replacement keeps length identical, so selection stays valid.
    final text = newValue.text.replaceAll(',', '.');
    if (!(signed ? _signed : _unsigned).hasMatch(text)) {
      return oldValue;
    }
    if (text == newValue.text) return newValue;
    // Text was rewritten under the IME: drop the composing region so the
    // keyboard's composing state can't point at content that changed.
    return newValue.copyWith(text: text, composing: TextRange.empty);
  }
}

/// Parse user-typed decimal text accepting both '.' and ',' separators.
/// Use this instead of `double.tryParse` for any text a user typed.
double? parseDecimal(String? text) {
  if (text == null) return null;
  return double.tryParse(text.trim().replaceAll(',', '.'));
}
