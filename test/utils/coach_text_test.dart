import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/coach_text.dart';

void main() {
  group('normalizeCoachText', () {
    test('adds final stop and capitalises start', () {
      expect(normalizeCoachText('small range c-bet with top set'),
          'Small range c-bet with top set.');
    });
    test('capitalises after stops', () {
      expect(normalizeCoachText('Nah, kid. raise was the move.'),
          'Nah, kid. Raise was the move.');
      expect(normalizeCoachText('Optimal. check is indicated.'),
          'Optimal. Check is indicated.');
    });
    test('newline heading becomes its own sentence', () {
      expect(
          normalizeCoachText('Flatting a suited ace in position\n'
              'ATs is a suited broadway ace, so it can make top pair'),
          'Flatting a suited ace in position. ATs is a suited broadway ace, '
          'so it can make top pair.');
    });
    test('collapses whitespace and fixes spacing', () {
      expect(normalizeCoachText('a  b , c ..  d\n\ne'), 'A b, c. D. E.');
    });
    test('keeps tokens, abbreviations, ellipsis, em-dash', () {
      expect(normalizeCoachText('BTN vs. LJ is tight. A♥ J♣ wants to call'),
          'BTN vs. LJ is tight. A♥ J♣ wants to call.');
      expect(normalizeCoachText('Wait… then raise — fine.'),
          'Wait… then raise — fine.');
      expect(normalizeCoachText('(Pure GTO would call.) then raise'),
          '(Pure GTO would call.) Then raise.');
    });
    test('idempotent', () {
      for (final s in [
        'a  b\n\nc',
        'Nah. raise (x) vs. y',
        'Wait… ok',
        '"quote" here',
        '9♠ 9♥ is a pair',
      ]) {
        final once = normalizeCoachText(s);
        expect(normalizeCoachText(once), once);
      }
    });
  });

  group('joinSentences', () {
    test('verbatim lead + reason', () {
      expect(
          joinSentences([
            'Snap raise, kid. Just like downtown.',
            'Hero range is capped here so we take the pot down',
          ]),
          'Snap raise, kid. Just like downtown. '
          'Hero range is capped here so we take the pot down.');
    });
    test('LEAK teaching + hand note', () {
      expect(
          joinSentences([
            'Hero range is capped here so we take the pot down',
            'But your A♥ J♣ specifically wants to call (100%) — the raise '
                'loses value.',
          ]),
          'Hero range is capped here so we take the pot down. '
          'But your A♥ J♣ specifically wants to call (100%) — the raise '
          'loses value.');
    });
    test('device example', () {
      expect(
          joinSentences([
            'The data disagrees — call is the line.',
            'Flatting a suited ace in position\nATs is a suited broadway ace',
            'But your ATs specifically wants to call (100%).',
          ]),
          'The data disagrees — call is the line. Flatting a suited ace in '
          'position. ATs is a suited broadway ace. But your ATs specifically '
          'wants to call (100%).');
    });
    test('skips null/blank, capitalises digits-led untouched', () {
      expect(joinSentences([null, '  ', '3-bet pot', 'x']), '3-bet pot. X.');
    });
  });
}
