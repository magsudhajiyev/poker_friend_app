import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/hand_details/hand_ai_analysis_card.dart';
import 'package:poker_logger/widgets/hand_details/hand_amount_formatter.dart';
import 'package:poker_logger/widgets/playing_card_face.dart';

void main() {
  group('HandAmountFormatter', () {
    const chips = HandAmountFormatter(showBB: false, bigBlind: 100, isCash: false);
    const bb = HandAmountFormatter(showBB: true, bigBlind: 100, isCash: false);

    test('toDouble is lenient with int/double and null', () {
      expect(HandAmountFormatter.toDouble(5), 5.0);
      expect(HandAmountFormatter.toDouble(5.5), 5.5);
      expect(HandAmountFormatter.toDouble('x'), isNull);
      expect(HandAmountFormatter.toDouble(null), isNull);
    });

    test('bb formats whole and fractional values', () {
      expect(bb.bb(1200), '12BB');
      expect(bb.bb(1250), '12.5BB');
    });

    test('bb falls back to 2.0 when bigBlind is not positive', () {
      const f = HandAmountFormatter(showBB: true, bigBlind: 0, isCash: true);
      expect(f.bb(10), '5BB');
    });

    test('amount and stack show dash for missing or non-positive', () {
      for (final v in [null, 0, -5, 'abc']) {
        expect(chips.amount(v), '-');
        expect(chips.stack(v), '-');
      }
    });

    test('amount honours BB toggle', () {
      expect(bb.amount(300), '3BB');
      expect(chips.amount(300), isNot('3BB'));
    });

    test('potAmount int does not crash (int cast regression)', () {
      expect(() => chips.summaryPot(1500), returnsNormally);
      expect(bb.summaryPot(1500), '15BB');
      expect(chips.summaryPot(null), isNotEmpty);
    });

    test('streetPot null for absent or zero', () {
      expect(chips.streetPot(null), isNull);
      expect(chips.streetPot(0), isNull);
      expect(bb.streetPot(500), '5BB');
    });

    test('amountStyle: preflop raise is raiseTo, others plain', () {
      AmountStyle s(String a, String st, dynamic amt) =>
          HandAmountFormatter.amountStyle(action: a, street: st, amount: amt);
      expect(s('raise', 'preflop', 600), AmountStyle.raiseTo);
      expect(s('all-in', 'preflop', 600), AmountStyle.raiseTo);
      expect(s('raise', 'flop', 600), AmountStyle.plain);
      expect(s('call', 'preflop', 600), AmountStyle.plain);
      expect(s('fold', 'preflop', null), AmountStyle.none);
      expect(s('raise', 'preflop', 0), AmountStyle.none);
    });
  });

  group('splitParagraphs', () {
    test('empty text gives no paragraphs', () {
      expect(splitParagraphs('  \n '), isEmpty);
    });
    test('splits on newlines', () {
      expect(splitParagraphs('a\n\nb\nc'), ['a', 'b', 'c']);
    });
    test('short single block stays whole', () {
      expect(splitParagraphs('One. Two. Three.'), ['One. Two. Three.']);
    });
    test('long single block groups sentences', () {
      final text = List.generate(6, (i) => 'Sentence number $i is here and long enough to count ${'x' * 40}.').join(' ');
      final out = splitParagraphs(text);
      expect(out.length, 3);
      expect(out.every((p) => p.endsWith('.')), isTrue);
    });
  });

  group('gradeColor', () {
    test('distinct tokens per grade, case-insensitive', () {
      expect(gradeColor('a'), gradeColor('A'));
      expect({for (final g in ['A', 'B', 'C', 'D', 'F']) gradeColor(g)}.length, 5);
    });
  });

  group('PlayingCardFace semantics', () {
    test('labels', () {
      expect(PlayingCardFace.semanticLabel('A♠'), 'Ace of spades');
      expect(PlayingCardFace.semanticLabel('T♦'), 'Ten of diamonds');
      expect(PlayingCardFace.semanticLabel('10♥'), 'Ten of hearts');
      expect(PlayingCardFace.semanticLabel('2♣'), 'Two of clubs');
    });
    test('unknown input falls back to raw text', () {
      expect(PlayingCardFace.semanticLabel('Z♠'), 'Z♠');
      expect(PlayingCardFace.semanticLabel('A'), 'A');
    });
    test('isRed', () {
      expect(PlayingCardFace.isRed('K♥'), isTrue);
      expect(PlayingCardFace.isRed('K♦'), isTrue);
      expect(PlayingCardFace.isRed('K♠'), isFalse);
    });
  });
}
