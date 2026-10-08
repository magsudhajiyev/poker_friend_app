import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/flop_strength.dart';

void main() {
  group('FlopStrengthClassifier', () {
    test('top pair is strong (the Q7s-on-Q63 review case)', () {
      expect(FlopStrengthClassifier.classify('Q♦7♦', ['Q♣', '6♥', '3♠']),
          FlopStrength.strong);
    });
    test('overpair is strong', () {
      expect(FlopStrengthClassifier.classify('T♦T♥', ['9♣', '6♥', '3♠']),
          FlopStrength.strong);
    });
    test('pocket pair below top card is weak pair', () {
      expect(FlopStrengthClassifier.classify('5♠5♣', ['K♣', '9♥', '3♠']),
          FlopStrength.weakPair);
    });
    test('middle pair is weak pair', () {
      expect(FlopStrengthClassifier.classify('9♦8♦', ['K♣', '9♥', '3♠']),
          FlopStrength.weakPair);
    });
    test('flush draw detected', () {
      expect(FlopStrengthClassifier.classify('A♦5♦', ['K♦', '9♦', '3♠']),
          FlopStrength.draw);
    });
    test('open-ended straight draw detected', () {
      expect(FlopStrengthClassifier.classify('8♣7♥', ['9♦', '6♥', '2♠']),
          FlopStrength.draw);
    });
    test('two overcards without pair or draw', () {
      expect(FlopStrengthClassifier.classify('A♣K♥', ['9♦', '6♥', '2♠']),
          FlopStrength.overcards);
    });
    test('no pair no draw is air', () {
      expect(FlopStrengthClassifier.classify('9♣3♦', ['K♦', '7♥', '2♠']),
          FlopStrength.air);
    });
    test('unparsable inputs return null', () {
      expect(FlopStrengthClassifier.classify(null, ['K♦', '7♥', '2♠']), isNull);
      expect(FlopStrengthClassifier.classify('Q♦7♦', null), isNull);
    });
  });
}
