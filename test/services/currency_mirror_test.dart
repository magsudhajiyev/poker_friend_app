import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/currency_service.dart';

void main() {
  group('CurrencyService.mirrorPayload', () {
    test('mirrors a known code', () {
      expect(CurrencyService.mirrorPayload('PLN'), {'currency': 'PLN'});
    });
    test('mirrors the default when nothing was chosen', () {
      expect(CurrencyService.mirrorPayload(null), {'currency': 'USD'});
    });
    test('falls back to USD for an unknown code', () {
      expect(CurrencyService.mirrorPayload('XXX'), {'currency': 'USD'});
    });
  });
}
