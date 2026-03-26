import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/stats_calculator.dart';
import '../fixtures/mock_hand_actions.dart';

void main() {
  group('StatsCalculator', () {
    group('isBlindAction', () {
      test('returns true for small blind', () {
        expect(StatsCalculator.isBlindAction({'action': 'small blind'}), isTrue);
      });

      test('returns true for big blind', () {
        expect(StatsCalculator.isBlindAction({'action': 'big blind'}), isTrue);
      });

      test('returns true for ante', () {
        expect(StatsCalculator.isBlindAction({'action': 'ante'}), isTrue);
      });

      test('returns false for call', () {
        expect(StatsCalculator.isBlindAction({'action': 'call'}), isFalse);
      });

      test('returns false for raise', () {
        expect(StatsCalculator.isBlindAction({'action': 'raise'}), isFalse);
      });

      test('handles case insensitivity', () {
        expect(StatsCalculator.isBlindAction({'action': 'SMALL BLIND'}), isTrue);
        expect(StatsCalculator.isBlindAction({'action': 'Big Blind'}), isTrue);
      });
    });

    group('3-Bet Detection', () {
      group('didPlayerThreeBet', () {
        test('returns true when hero raises after opponent raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0), // Villain opens
            MockHandActions.raise(4, 18.0), // Hero 3-bets
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);
        });

        test('returns false when hero open-raises with no prior raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.raise(4, 6.0), // Hero opens, no prior raise
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero calls instead of 3-betting', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0), // Villain opens
            MockHandActions.call(4, 6.0), // Hero flat calls
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('ignores non-preflop raises', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),
            MockHandActions.check(4),
            // Flop
            MockHandActions.bet(3, 5.0, street: 'flop'),
            MockHandActions.raise(4, 15.0, street: 'flop'), // Flop raise, not 3-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('detects 3-bet when multiple players involved', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0), // UTG opens
            MockHandActions.call(4, 6.0), // MP calls
            MockHandActions.raise(5, 20.0), // CO 3-bets
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero folds after seeing raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.fold(4),
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false for original raiser who 4-bets (not a 3-bet)', () {
          // Player 3 opens, Player 4 3-bets, Player 3 4-bets
          // Only Player 4 made a 3-bet, Player 3 made a 4-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // Player 3 opens (2-bet)
            MockHandActions.raise(4, 18.0),  // Player 4 3-bets
            MockHandActions.raise(3, 50.0),  // Player 3 4-bets
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // Player 4 made the 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // Player 3 made 4-bet, not 3-bet
        });

        test('handles 5-bet scenario correctly', () {
          // Player 3 opens, Player 4 3-bets, Player 3 4-bets, Player 4 5-bets
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),    // 2-bet
            MockHandActions.raise(4, 18.0),   // 3-bet
            MockHandActions.raise(3, 50.0),   // 4-bet
            MockHandActions.raise(4, 120.0),  // 5-bet
          ];

          // Only Player 4's first raise (18.0) is a 3-bet
          // Player 4's second raise (120.0) is a 5-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
        });

        test('returns true for correct player in multiway 3-bet pot', () {
          // UTG opens, MP calls, CO 3-bets
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0, position: 'UTG'),   // UTG opens
            MockHandActions.call(4, 6.0, position: 'MP'),     // MP calls
            MockHandActions.raise(5, 20.0, position: 'CO'),   // CO 3-bets
            MockHandActions.fold(6, position: 'BTN'),
            MockHandActions.call(3, 14.0),                    // UTG calls
            MockHandActions.call(4, 14.0),                    // MP calls
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);   // CO 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);  // UTG opened
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);  // MP just called
        });
      });

      group('hadThreeBetOpportunity', () {
        test('returns true when player acts after seeing a raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0), // Someone raises
            MockHandActions.call(4, 6.0), // Hero acts after
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
        });

        test('returns true when player folds after seeing a raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.fold(4),
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
        });

        test('returns false when player acts before any raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3), // Hero folds before any raise
            MockHandActions.raise(4, 6.0), // Someone raises after
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        });

        test('returns false when no raises in hand', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),
            MockHandActions.check(4),
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isFalse);
        });
      });
    });

    group('Fold to 3-Bet Detection', () {
      group('facedThreeBet', () {
        test('returns true when hero raises then faces re-raise', () {
          final actions = MockHandActions.heroFaces3Bet(heroSeat: 3);
          expect(StatsCalculator.facedThreeBet(actions, 3), isTrue);
        });

        test('returns false when hero raises and all fold', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.fold(4),
            MockHandActions.fold(5),
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero calls instead of raising', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),
            MockHandActions.raise(4, 8.0),
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero raises but villain just calls', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.call(4, 6.0),
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });
      });

      group('didFoldTo3Bet', () {
        test('returns true when hero raises, faces 3-bet, then folds', () {
          final actions = MockHandActions.heroFoldsTo3Bet(heroSeat: 3);
          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isTrue);
        });

        test('returns false when hero raises, faces 3-bet, then calls', () {
          final actions = MockHandActions.heroCallsTo3Bet(heroSeat: 3);
          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });

        test('returns false when hero raises, faces 3-bet, then 4-bets', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0),
            MockHandActions.raise(3, 50.0), // 4-bet
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });

        test('returns false when hero folds without facing 3-bet', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });
      });
    });

    group('C-Bet Detection', () {
      group('hadCbetOpportunity', () {
        test('returns true when hero raises pre and sees flop', () {
          final actions = MockHandActions.cbetOpportunity(heroSeat: 3);
          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
        });

        test('returns false when hero raises pre but all fold preflop', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.fold(4),
            MockHandActions.fold(1),
            MockHandActions.fold(2),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isFalse);
        });

        test('returns false when hero calls pre and sees flop', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 6.0),
            MockHandActions.check(4, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isFalse);
        });

        test('returns false when hero raises but villain 3-bets and sees flop', () {
          // Hero is not last aggressor if villain 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0), // Villain 3-bets
            MockHandActions.call(3, 12.0),
            MockHandActions.check(3, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isFalse);
          expect(StatsCalculator.hadCbetOpportunity(actions, 4), isTrue); // Villain has c-bet opp
        });
      });

      group('didCbet', () {
        test('returns true when hero raises pre and bets flop', () {
          final actions = MockHandActions.heroCbets(heroSeat: 3);
          expect(StatsCalculator.didCbet(actions, 3), isTrue);
        });

        test('returns false when hero raises pre and checks flop', () {
          final actions = MockHandActions.heroChecksFlopNoCbet(heroSeat: 3);
          expect(StatsCalculator.didCbet(actions, 3), isFalse);
        });

        test('returns false when hero calls pre and bets flop (not last aggressor)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 6.0),
            MockHandActions.check(4, street: 'flop'),
            MockHandActions.bet(3, 8.0, street: 'flop'),
          ];

          expect(StatsCalculator.didCbet(actions, 3), isFalse);
        });

        test('returns false when hero raises pre but villain bets first on flop', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.call(4, 6.0),
            MockHandActions.bet(4, 8.0, street: 'flop'), // Villain bets first
          ];

          // Hero didn't get to bet (no c-bet opportunity wasn't taken)
          // But hero still has c-bet opportunity, just didn't c-bet
          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
          expect(StatsCalculator.didCbet(actions, 3), isFalse);
        });

        test('returns false when hero raises pre then raises on flop (raise is not c-bet)', () {
          // C-bet must be a BET, not a raise
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.call(4, 6.0),
            MockHandActions.bet(4, 8.0, street: 'flop'),
            MockHandActions.raise(3, 24.0, street: 'flop'), // Hero raises, not bets
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
          expect(StatsCalculator.didCbet(actions, 3), isFalse); // Raise is not a c-bet
        });

        test('handles multiway pot c-bet opportunity correctly', () {
          // Hero raises, two callers, hero has c-bet opportunity
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.call(4, 6.0),
            MockHandActions.call(5, 6.0),
            MockHandActions.check(4, street: 'flop'),
            MockHandActions.check(5, street: 'flop'),
            MockHandActions.bet(3, 10.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
          expect(StatsCalculator.didCbet(actions, 3), isTrue);
          expect(StatsCalculator.hadCbetOpportunity(actions, 4), isFalse);
          expect(StatsCalculator.hadCbetOpportunity(actions, 5), isFalse);
        });
      });
    });

    group('Steal Detection', () {
      group('hadStealOpportunity', () {
        test('returns true for BTN with unopened pot', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            // Hero in BTN has action available
          ];
          // Add hero's first action to establish position
          actions.add(MockHandActions.check(6, position: 'BTN'));

          expect(StatsCalculator.hadStealOpportunity(actions, 6), isTrue);
        });

        test('returns true for CO with unopened pot', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
          ];
          actions.add(MockHandActions.check(5, position: 'CO'));

          expect(StatsCalculator.hadStealOpportunity(actions, 5), isTrue);
        });

        test('returns true for SB with unopened pot', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.fold(6, position: 'BTN'),
          ];
          // SB has steal opportunity now

          expect(StatsCalculator.hadStealOpportunity(actions, 1), isTrue);
        });

        test('returns false for UTG with unopened pot (not steal position)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
          ];
          actions.add(MockHandActions.check(3, position: 'UTG'));

          expect(StatsCalculator.hadStealOpportunity(actions, 3), isFalse);
        });

        test('returns false for BTN when pot is opened by limper', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'), // Limper opens pot
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
          ];
          actions.add(MockHandActions.check(6, position: 'BTN'));

          expect(StatsCalculator.hadStealOpportunity(actions, 6), isFalse);
        });

        test('returns false for BTN when pot is opened by raiser', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
          ];
          actions.add(MockHandActions.check(6, position: 'BTN'));

          expect(StatsCalculator.hadStealOpportunity(actions, 6), isFalse);
        });
      });

      group('didSteal', () {
        test('returns true when BTN raises with unopened pot', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.raise(6, 5.0, position: 'BTN'),
          ];

          expect(StatsCalculator.didSteal(actions, 6), isTrue);
        });

        test('returns false when BTN folds with steal opportunity', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.fold(6, position: 'BTN'),
          ];

          expect(StatsCalculator.didSteal(actions, 6), isFalse);
        });

        test('returns false when CO raises after limper (pot opened)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.raise(5, 8.0, position: 'CO'),
          ];

          expect(StatsCalculator.didSteal(actions, 5), isFalse);
        });

        test('returns false for BB position (BB is not a steal position)', () {
          // BB cannot steal - they already have money in
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.fold(6, position: 'BTN'),
            MockHandActions.fold(1, position: 'SB'),
          ];
          // BB "wins" but this is a walk, not a steal
          // BB never has steal opportunity

          expect(StatsCalculator.hadStealOpportunity(actions, 2), isFalse);
          expect(StatsCalculator.didSteal(actions, 2), isFalse);
        });

        test('returns false for MP position even with unopened pot', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.raise(4, 6.0, position: 'MP'),
          ];

          expect(StatsCalculator.hadStealOpportunity(actions, 4), isFalse);
          expect(StatsCalculator.didSteal(actions, 4), isFalse);
        });

        test('SB steal is counted correctly', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.fold(6, position: 'BTN'),
            MockHandActions.raise(1, 4.0, position: 'SB'), // SB completes to raise
          ];

          expect(StatsCalculator.hadStealOpportunity(actions, 1), isTrue);
          expect(StatsCalculator.didSteal(actions, 1), isTrue);
        });
      });
    });

    group('Check/Raise Detection', () {
      group('hadCheckRaiseFlopOpportunity', () {
        test('returns true when hero checks and faces bet on flop', () {
          final actions = MockHandActions.checkRaiseOpportunity(heroSeat: 3);
          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isTrue);
        });

        test('returns false when hero checks and everyone checks behind', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 4.0),
            MockHandActions.check(3, street: 'flop'),
            MockHandActions.check(4, street: 'flop'),
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isFalse);
        });

        test('returns false when hero bets immediately on flop', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 4.0),
            MockHandActions.bet(3, 8.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isFalse);
        });

        test('returns false for turn check (flop only)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),
            MockHandActions.check(4),
            MockHandActions.check(3, street: 'flop'),
            MockHandActions.check(4, street: 'flop'),
            MockHandActions.check(3, street: 'turn'),
            MockHandActions.bet(4, 5.0, street: 'turn'),
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isFalse);
        });
      });

      group('didCheckRaiseFlop', () {
        test('returns true when hero checks, faces bet, then raises on flop', () {
          final actions = MockHandActions.heroCheckRaises(heroSeat: 3);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isTrue);
        });

        test('returns false when hero checks, faces bet, then calls on flop', () {
          final actions = MockHandActions.heroCallsFlop(heroSeat: 3);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isFalse);
        });

        test('returns false when hero checks, faces bet, then folds on flop', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 4.0),
            MockHandActions.check(3, street: 'flop'),
            MockHandActions.bet(4, 8.0, street: 'flop'),
            MockHandActions.fold(3, street: 'flop'),
          ];

          expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isFalse);
        });

        test('returns false when hero bets then raises (not check-raise)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(4, 6.0),
            MockHandActions.call(3, 4.0),
            MockHandActions.bet(3, 8.0, street: 'flop'),
            MockHandActions.raise(4, 24.0, street: 'flop'),
            MockHandActions.raise(3, 60.0, street: 'flop'),
          ];

          expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isFalse);
        });

        test('check-raise works against any position (not just late position)', () {
          // BB checks, UTG bets, BB raises - UTG is early position
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(3, 6.0, position: 'UTG'),
            MockHandActions.call(2, 4.0, position: 'BB'),
            MockHandActions.fold(1, position: 'SB'),
            // Flop - BB is OOP vs UTG
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(3, 8.0, street: 'flop'),  // UTG (early position) bets
            MockHandActions.raise(2, 24.0, street: 'flop'), // BB check-raises
          ];

          // Check-raise should work against UTG (early position), not just BTN
          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 2), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 2), isTrue);
        });

        test('check-raise works in 3-way pot', () {
          // SB checks, BB checks, BTN bets, SB raises
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(6, 6.0, position: 'BTN'),
            MockHandActions.call(1, 5.0, position: 'SB'),
            MockHandActions.call(2, 4.0, position: 'BB'),
            // Flop - 3-way
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(6, 10.0, street: 'flop'),
            MockHandActions.raise(1, 30.0, street: 'flop'), // SB check-raises
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 1), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 1), isTrue);
          // BB also had opportunity after SB checked
          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 2), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 2), isFalse); // BB didn't raise
        });

        test('in position player cannot check-raise (they act last)', () {
          // BTN raises pre, BB calls
          // BB bets flop, BTN cannot check-raise (they're IP)
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(6, 6.0, position: 'BTN'),
            MockHandActions.fold(1),
            MockHandActions.call(2, 4.0, position: 'BB'),
            // Flop - BTN is IP, BB is OOP
            MockHandActions.bet(2, 8.0, street: 'flop'),  // BB leads
            MockHandActions.raise(6, 24.0, street: 'flop'), // BTN raises (not a check-raise)
          ];

          // BTN didn't check, so cannot have check-raise opportunity
          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 6), isFalse);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 6), isFalse);
        });
      });
    });

    group('Walk Detection', () {
      group('isWalkHand', () {
        test('returns true when everyone folds to BB', () {
          final actions = MockHandActions.walkHand(playerCount: 6);
          expect(StatsCalculator.isWalkHand(actions), isTrue);
        });

        test('returns false when someone calls', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.call(4, 2.0),
          ];

          expect(StatsCalculator.isWalkHand(actions), isFalse);
        });

        test('returns false when someone raises', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
          ];

          expect(StatsCalculator.isWalkHand(actions), isFalse);
        });

        test('BB does not need to check in a walk (hand ends when SB folds)', () {
          // In a true walk, BB doesn't take any action because the hand
          // ends immediately when everyone folds. The BB just wins the pot.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.fold(4),
            MockHandActions.fold(5),
            MockHandActions.fold(6),
            MockHandActions.fold(1), // SB folds - hand ends here as a walk
          ];

          expect(StatsCalculator.isWalkHand(actions), isTrue);
        });

        test('returns false with empty actions', () {
          expect(StatsCalculator.isWalkHand([]), isFalse);
        });

        test('returns false when only blinds posted (no folds)', () {
          final actions = MockHandActions.blindsOnly();
          expect(StatsCalculator.isWalkHand(actions), isFalse);
        });
      });

      group('isBigBlind', () {
        test('returns true when player posts big blind', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isBigBlind(actions, 2), isTrue);
        });

        test('returns true when player has BB position', () {
          final actions = [
            {'player': 2, 'action': 'check', 'playerPosition': 'BB'},
          ];

          expect(StatsCalculator.isBigBlind(actions, 2), isTrue);
        });

        test('returns false when player is SB', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isBigBlind(actions, 1), isFalse);
        });

        test('returns false when different player is BB', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isBigBlind(actions, 3), isFalse);
        });
      });
    });

    group('Edge Cases', () {
      test('handles empty action list gracefully', () {
        final emptyActions = <Map<String, dynamic>>[];

        expect(StatsCalculator.didPlayerThreeBet(emptyActions, 1), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(emptyActions, 1), isFalse);
        expect(StatsCalculator.facedThreeBet(emptyActions, 1), isFalse);
        expect(StatsCalculator.didFoldTo3Bet(emptyActions, 1), isFalse);
        expect(StatsCalculator.hadCbetOpportunity(emptyActions, 1), isFalse);
        expect(StatsCalculator.didCbet(emptyActions, 1), isFalse);
        expect(StatsCalculator.hadStealOpportunity(emptyActions, 1), isFalse);
        expect(StatsCalculator.didSteal(emptyActions, 1), isFalse);
        expect(StatsCalculator.hadCheckRaiseFlopOpportunity(emptyActions, 1), isFalse);
        expect(StatsCalculator.didCheckRaiseFlop(emptyActions, 1), isFalse);
        expect(StatsCalculator.isWalkHand(emptyActions), isFalse);
        expect(StatsCalculator.isBigBlind(emptyActions, 1), isFalse);
      });

      test('handles missing street field', () {
        final actions = [
          {'player': 1, 'action': 'raise', 'amount': 6.0},
          {'player': 2, 'action': 'call', 'amount': 6.0},
        ];

        // Should not crash, defaults to checking preflop
        expect(StatsCalculator.didPlayerThreeBet(actions, 2), isFalse);
      });

      test('handles missing player field', () {
        final actions = [
          {'action': 'raise', 'street': 'preflop', 'amount': 6.0},
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 1), isFalse);
      });

      test('handles case insensitivity for action types', () {
        final actions = [
          {'player': 1, 'action': 'RAISE', 'street': 'PREFLOP', 'amount': 6.0},
          {'player': 2, 'action': 'Raise', 'street': 'Preflop', 'amount': 18.0},
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 2), isTrue);
      });

      test('handles player seat that does not exist in actions', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 99), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 99), isFalse);
      });

      test('all-in after raise should be detected as 3-bet', () {
        // Industry standard: All-in is functionally equivalent to a bet or raise
        // If a player goes all-in over an open-raise, it MUST be counted as a 3-bet
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
          {'player': 4, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0},
        ];

        // Correct behavior: all-in over a raise IS a 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);
      });

      test('all-in as open should give 3-bet opportunity to others', () {
        // If UTG goes all-in (effectively a raise), everyone after has 3-bet opportunity
        final actions = [
          ...MockHandActions.blindsOnly(),
          {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0},
          MockHandActions.fold(4),
        ];

        // Correct behavior: all-in open = raise, so player 4 had 3-bet opportunity
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
      });

      test('all-in on flop should count for c-bet if last preflop aggressor', () {
        // If hero raises pre and goes all-in on flop, it should count as c-bet
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
          MockHandActions.call(4, 6.0),
          {'player': 4, 'action': 'check', 'street': 'flop'},
          {'player': 3, 'action': 'all-in', 'street': 'flop', 'amount': 50.0},
        ];

        // Correct behavior: all-in on flop by preflop aggressor IS a c-bet
        expect(StatsCalculator.didCbet(actions, 3), isTrue);
      });

      test('handles bet vs raise distinction on flop', () {
        // First bet on a street is a 'bet', subsequent is 'raise'
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
          MockHandActions.call(4, 6.0),
          MockHandActions.bet(3, 10.0, street: 'flop'),    // This is a bet
          MockHandActions.raise(4, 30.0, street: 'flop'), // This is a raise
        ];

        // Player 3 c-bet (they bet on flop as last pre aggressor)
        expect(StatsCalculator.didCbet(actions, 3), isTrue);
      });

      test('multiple players with 3-bet opportunity in same hand', () {
        // UTG opens, everyone after has 3-bet opportunity
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.call(5, 6.0, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.call(2, 4.0, position: 'BB'),
        ];

        // UTG opened, so no 3-bet opportunity (nothing to 3-bet)
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        // Everyone else had 3-bet opportunity but didn't take it
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 5), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 6), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 1), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 2), isTrue);

        // None of them 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse);
      });

      test('check-raise on turn is not counted as flop check-raise', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(4, 6.0),
          MockHandActions.call(3, 4.0),
          MockHandActions.check(3, street: 'flop'),
          MockHandActions.check(4, street: 'flop'),
          MockHandActions.check(3, street: 'turn'),
          MockHandActions.bet(4, 10.0, street: 'turn'),
          MockHandActions.raise(3, 30.0, street: 'turn'), // Check-raise on turn
        ];

        // Check-raise happened on turn, not flop
        expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isFalse);
        expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isFalse);
      });

      test('heads up walk scenario', () {
        // In heads up, if BTN/SB folds, BB gets a walk
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.fold(1), // SB folds
        ];

        expect(StatsCalculator.isWalkHand(actions), isTrue);
        expect(StatsCalculator.isBigBlind(actions, 2), isTrue);
        expect(StatsCalculator.isBigBlind(actions, 1), isFalse);
      });

      test('limp-reraise is not a 3-bet', () {
        // UTG limps, BTN raises, UTG re-raises (limp-reraise)
        // This is a 3-bet by UTG
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.call(3, 2.0, position: 'UTG'),   // UTG limps
          MockHandActions.raise(6, 8.0, position: 'BTN'),  // BTN raises (iso-raise)
          MockHandActions.raise(3, 24.0, position: 'UTG'), // UTG re-raises (limp-reraise)
        ];

        // BTN raised first, so BTN did not 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse);
        // UTG raised after seeing BTN's raise, so this IS a 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 3), isTrue);
      });
    });
  });
}
