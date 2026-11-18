import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/meta_attribution_service.dart';

void main() {
  group('metaPurchaseKind', () {
    test('trial purchase maps to start_trial, not purchase', () {
      expect(metaPurchaseKind(inTrial: true), MetaPurchaseKind.startTrial);
    });
    test('paid purchase maps to purchase', () {
      expect(metaPurchaseKind(inTrial: false), MetaPurchaseKind.purchase);
    });
  });

  group('metaRegistrationMethod', () {
    test('maps known providers', () {
      expect(metaRegistrationMethod('password'), 'email');
      expect(metaRegistrationMethod('google.com'), 'google');
      expect(metaRegistrationMethod('apple.com'), 'apple');
    });
    test('skips guests and unknown providers', () {
      expect(metaRegistrationMethod('anonymous'), isNull);
      expect(metaRegistrationMethod(''), isNull);
    });
  });
}
