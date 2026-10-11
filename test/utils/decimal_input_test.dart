import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/decimal_input.dart';

TextEditingValue _apply(TextInputFormatter f, String oldText, String newText) {
  return f.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(
        text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  group('DecimalInputFormatter', () {
    final f = DecimalInputFormatter();

    test('normalizes comma to dot (the 25,00 → 2500 blind bug)', () {
      expect(_apply(f, '50', '50,').text, '50.');
      expect(_apply(f, '50.', '50.0').text, '50.0');
      expect(_apply(f, '25', '25,00').text, '25.00');
    });

    test('plain digits and dot pass through', () {
      expect(_apply(f, '', '5').text, '5');
      expect(_apply(f, '5', '5.').text, '5.');
      expect(_apply(f, '5.', '5.5').text, '5.5');
    });

    test('rejects a second decimal separator', () {
      expect(_apply(f, '5.5', '5.5.').text, '5.5');
      expect(_apply(f, '5.5', '5.5,').text, '5.5');
    });

    test('rejects letters and minus when unsigned', () {
      expect(_apply(f, '5', '5a').text, '5');
      expect(_apply(f, '', '-').text, '');
    });

    test('signed variant allows a leading minus only', () {
      final signed = DecimalInputFormatter(signed: true);
      expect(_apply(signed, '', '-').text, '-');
      expect(_apply(signed, '-', '-12,5').text, '-12.5');
      expect(_apply(signed, '-1', '-1-').text, '-1');
    });
  });

  group('parseDecimal', () {
    test('accepts both separators', () {
      expect(parseDecimal('50,00'), 50.0);
      expect(parseDecimal('50.00'), 50.0);
      expect(parseDecimal('0,25'), 0.25);
      expect(parseDecimal(' 12,5 '), 12.5);
      expect(parseDecimal('-3,5'), -3.5);
    });

    test('returns null for garbage', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal(null), isNull);
      expect(parseDecimal('abc'), isNull);
    });
  });
}
