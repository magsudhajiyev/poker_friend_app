import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/onboarding/onboarding_motion.dart';

void main() {
  group('staggerInterval', () {
    test('bounds stay within 0..1 and begin <= end', () {
      for (var total = 1; total <= 6; total++) {
        for (var i = -1; i <= total + 2; i++) {
          final iv = staggerInterval(i, total,
              stepFraction: 0.4, durationFraction: 0.9);
          expect(iv.begin, inInclusiveRange(0.0, 1.0));
          expect(iv.end, inInclusiveRange(0.0, 1.0));
          expect(iv.begin <= iv.end, isTrue);
        }
      }
    });

    test('begin is monotonic non-decreasing in index', () {
      var prev = -1.0;
      for (var i = 0; i < 3; i++) {
        final b = staggerInterval(i, 3).begin;
        expect(b, greaterThanOrEqualTo(prev));
        prev = b;
      }
    });

    test('first item starts at 0', () {
      expect(staggerInterval(0, 3).begin, 0);
    });
  });
}
