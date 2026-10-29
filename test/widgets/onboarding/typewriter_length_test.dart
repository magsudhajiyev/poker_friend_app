import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/onboarding/onboarding_motion.dart';

void main() {
  group('typewriterLength', () {
    test('zero elapsed or empty text gives 0', () {
      expect(typewriterLength(Duration.zero, 10), 0);
      expect(typewriterLength(const Duration(seconds: 1), 0), 0);
    });

    test('partial progress at 35 chars/s', () {
      expect(typewriterLength(const Duration(seconds: 1), 100), 35);
      expect(typewriterLength(const Duration(milliseconds: 500), 100), 17);
    });

    test('clamps to full length', () {
      expect(typewriterLength(const Duration(seconds: 60), 12), 12);
    });
  });
}
