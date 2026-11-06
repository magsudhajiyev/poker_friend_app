import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/stats_calculator.dart';

/// Hands with a dead small blind or dead button have fewer blind posts and
/// an empty button seat. Detection relies on the stored `playerPosition`
/// labels (which are real in those hands) and must not assume the first
/// blind post is the SB or the second the BB.
void main() {
  Map<String, dynamic> a(int p, String act, String pos,
          {String street = 'preflop', double? amount}) =>
      {
        'player': p,
        'action': act,
        'street': street,
        'playerPosition': pos,
        if (amount != null) 'amount': amount,
      };

  group('dead small blind (seat 3 empty): BTN2 BB4 UTG5 HJ6 CO1', () {
    test('BB is found from a lone big blind post; there is no SB', () {
      final actions = [
        {'player': 4, 'action': 'big blind', 'street': 'preflop'},
        a(5, 'fold', 'UTG'),
      ];
      expect(StatsCalculator.findBigBlindSeat(actions), 4);
      expect(StatsCalculator.findSmallBlindSeat(actions), isNull);
      expect(StatsCalculator.isSmallBlind(actions, 3), isFalse);
    });

    test('BB found from its position label', () {
      final actions = [a(5, 'fold', 'UTG'), a(4, 'check', 'BB')];
      expect(StatsCalculator.findBigBlindSeat(actions), 4);
      expect(StatsCalculator.isBigBlind(actions, 4), isTrue);
    });

    test('everyone folds to the BB is still a walk', () {
      final actions = [
        a(5, 'fold', 'UTG'),
        a(6, 'fold', 'HJ'),
        a(1, 'fold', 'CO'),
        a(2, 'fold', 'BTN'),
      ];
      expect(StatsCalculator.isWalkHand(actions), isTrue);
    });

    test('CO still has a steal opportunity when folded to; BB can defend', () {
      final actions = [
        a(5, 'fold', 'UTG'),
        a(6, 'fold', 'HJ'),
        a(1, 'raise', 'CO', amount: 5),
        a(2, 'fold', 'BTN'),
        a(4, 'call', 'BB', amount: 5),
      ];
      expect(StatsCalculator.hadStealOpportunity(actions, 1), isTrue);
      expect(StatsCalculator.didSteal(actions, 1), isTrue);
      expect(StatsCalculator.hadBlindDefendOpportunity(actions, 4), isTrue);
      expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isFalse);
    });
  });

  group('dead button (seat 3 empty): SB4 BB5 UTG6 HJ1 CO2', () {
    test('nobody is labelled BTN; CO and SB keep steal opportunities', () {
      final actions = [
        a(6, 'fold', 'UTG'),
        a(1, 'fold', 'HJ'),
        a(2, 'raise', 'CO', amount: 5),
        a(4, 'fold', 'SB'),
        a(5, 'fold', 'BB'),
      ];
      expect(StatsCalculator.hadStealOpportunity(actions, 2), isTrue);
      expect(StatsCalculator.findBigBlindSeat(actions), 5);
      expect(StatsCalculator.findSmallBlindSeat(actions), 4);
      expect(StatsCalculator.isWalkHand(actions), isFalse);
    });
  });
}
