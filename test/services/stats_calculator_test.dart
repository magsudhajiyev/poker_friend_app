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
      // 3-bet = the 3rd raise preflop
      // 1st raise = open, 2nd raise = re-raise, 3rd raise = 3-bet

      group('didPlayerThreeBet', () {
        test('returns true when player makes the 3rd raise', () {
          // P3 opens (1st), P4 raises (2nd), P5 raises (3rd = 3-bet)
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise (open)
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(5, 50.0),  // 3rd raise = 3-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when player makes only the 2nd raise (not a 3-bet)', () {
          // P3 opens (1st), P4 raises (2nd) — this is just a raise, not 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // 2nd raise — NOT a 3-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero open-raises with no prior raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.raise(4, 6.0), // Hero opens, 1st raise
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero calls instead of 3-betting', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),  // 1st raise
            MockHandActions.raise(4, 18.0), // 2nd raise
            MockHandActions.call(5, 18.0),  // Hero calls
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse);
        });

        test('ignores non-preflop raises', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),
            MockHandActions.check(4),
            // Flop
            MockHandActions.bet(3, 5.0, street: 'flop'),
            MockHandActions.raise(4, 15.0, street: 'flop'),
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('original opener who 4-bets is not 3-betting', () {
          // P3 opens (1st), P4 raises (2nd), P3 raises again (3rd = 3-bet by P3)
          // Wait — P3 made the 3rd raise, so P3 IS the 3-bettor here
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(3, 50.0),  // 3rd raise = 3-bet by P3
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isTrue); // P3 made 3rd raise
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse); // P4 made 2nd raise
        });

        test('handles 4-bet and 5-bet scenario correctly', () {
          // P3 opens (1st), P4 raises (2nd), P3 raises (3rd=3-bet), P4 raises (4th=4-bet)
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),    // 1st raise
            MockHandActions.raise(4, 18.0),   // 2nd raise
            MockHandActions.raise(3, 50.0),   // 3rd raise = 3-bet
            MockHandActions.raise(4, 120.0),  // 4th raise = 4-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isTrue);  // 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse); // 4-bet, not 3-bet
        });

        test('returns true for correct player in multiway 3-bet pot', () {
          // UTG opens (1st), MP raises (2nd), CO raises (3rd = 3-bet)
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0, position: 'UTG'),   // 1st raise
            MockHandActions.raise(4, 18.0, position: 'MP'),   // 2nd raise
            MockHandActions.raise(5, 50.0, position: 'CO'),   // 3rd raise = 3-bet
            MockHandActions.fold(6, position: 'BTN'),
            MockHandActions.call(3, 44.0),                    // UTG calls
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);   // CO 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);  // UTG opened
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);  // MP 2nd raise
        });

        test('returns false when hero folds after seeing raises', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st
            MockHandActions.raise(4, 18.0),  // 2nd
            MockHandActions.fold(5),         // Hero folds instead of 3-betting
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse);
        });

        test('all-in as 3rd raise is a 3-bet', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // 2nd raise
            {'player': 5, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 3rd = 3-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);
        });

        test('limp-raise sequence: raise after limper raise is 2nd raise not 3-bet', () {
          // UTG limps, BTN raises (1st raise), UTG re-raises (2nd raise)
          // Only 2 raises total — no 3-bet happened
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'),   // UTG limps
            MockHandActions.raise(6, 8.0, position: 'BTN'),  // BTN raises (1st raise)
            MockHandActions.raise(3, 24.0, position: 'UTG'), // UTG re-raises (2nd raise)
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse); // 1st raise
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // 2nd raise, not 3-bet
        });

        test('limp-raise with 3rd raise IS a 3-bet', () {
          // UTG limps, BTN raises (1st), UTG re-raises (2nd), BTN raises (3rd = 3-bet)
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'),
            MockHandActions.raise(6, 8.0, position: 'BTN'),  // 1st raise
            MockHandActions.raise(3, 24.0, position: 'UTG'), // 2nd raise
            MockHandActions.raise(6, 70.0, position: 'BTN'), // 3rd raise = 3-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 6), isTrue);
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
        });
      });

      group('hadThreeBetOpportunity', () {
        test('returns true when player can make 3rd raise (2 raises already happened)', () {
          // P3 opens (1st), P4 raises (2nd), P5 acts after — can 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.fold(5),         // P5 acts after 2 raises
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 5), isTrue);
        });

        test('returns false when only 1 raise happened before player acts', () {
          // P3 opens (1st raise only), P4 acts — only 1 raise, can raise but not 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise only
            MockHandActions.call(4, 6.0),    // P4 acts after 1 raise
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isFalse);
        });

        test('returns false when player acts before any raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.raise(4, 6.0),
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

        test('opener has 3-bet opportunity when facing 2nd raise', () {
          // P3 opens (1st), P4 raises (2nd), action back to P3 — P3 can 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise by P3
            MockHandActions.raise(4, 18.0),  // 2nd raise by P4
            MockHandActions.call(3, 12.0),   // P3 acts after 2 total raises — can 3-bet
          ];

          // 2 total raises happened when P3 acts again → 3-bet opportunity
          expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isTrue);
        });

        test('no 3-bet opportunity when 3+ raises already happened (4-bet territory)', () {
          // P3 opens (1st), P4 raises (2nd), P5 raises (3rd = 3-bet)
          // When P3 acts again, 3 raises already happened — this is 4-bet opp, not 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(5, 50.0),  // 3rd raise = 3-bet
            MockHandActions.fold(3),         // P3 acts after 3 raises — 4-bet territory
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        });
      });
    });

    group('Fold to 3-Bet Detection', () {
      group('facedThreeBet', () {
        test('returns true when hero opens, someone raises, someone 3-bets', () {
          // Hero opens (1st), P4 raises (2nd), P5 raises (3rd = 3-bet)
          // Hero raised earlier and now faces the 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // Hero opens
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(5, 50.0),  // 3rd raise = 3-bet
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isTrue);
        });

        test('returns true when hero re-raises and opponent 3-bets', () {
          // P3 opens (1st), Hero raises (2nd), P3 raises (3rd = 3-bet)
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),    // 1st raise
            MockHandActions.raise(4, 18.0),   // Hero 2nd raise
            MockHandActions.raise(3, 50.0),   // 3rd raise = 3-bet
          ];

          expect(StatsCalculator.facedThreeBet(actions, 4), isTrue);
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

        test('returns false when only 2 raises happen (no 3-bet)', () {
          // P3 opens (1st), P4 raises (2nd) — only 2 raises, no 3-bet
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise by hero
            MockHandActions.raise(4, 18.0),  // 2nd raise — not a 3-bet yet
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero did not raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0),
            MockHandActions.raise(5, 50.0), // 3-bet happened but hero (P6) never raised
          ];

          expect(StatsCalculator.facedThreeBet(actions, 6), isFalse);
        });
      });

      group('didFoldTo3Bet', () {
        test('returns true when hero opens, faces 3-bet, then folds', () {
          // P3 opens (1st), P4 raises (2nd), P5 3-bets (3rd), P3 folds
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // Hero opens
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(5, 50.0),  // 3rd raise = 3-bet
            MockHandActions.fold(3),         // Hero folds to 3-bet
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isTrue);
        });

        test('returns true when hero re-raises, opponent 3-bets, hero folds', () {
          // P3 opens (1st), Hero raises (2nd), P3 3-bets (3rd), Hero folds
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // 1st raise
            MockHandActions.raise(4, 18.0),  // Hero 2nd raise
            MockHandActions.raise(3, 50.0),  // 3rd raise = 3-bet
            MockHandActions.fold(4),         // Hero folds
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 4), isTrue);
        });

        test('returns false when hero faces 3-bet but calls', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0),
            MockHandActions.raise(5, 50.0),  // 3-bet
            MockHandActions.call(3, 44.0),   // Hero calls
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });

        test('returns false when hero faces 3-bet but 4-bets', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // Hero opens
            MockHandActions.raise(4, 18.0),  // 2nd raise
            MockHandActions.raise(5, 50.0),  // 3rd = 3-bet
            MockHandActions.raise(3, 120.0), // Hero 4-bets
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

        test('returns false when only 2 raises and hero folds', () {
          // Only 2 raises — no 3-bet happened
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // Hero opens
            MockHandActions.raise(4, 18.0),  // 2nd raise (not 3-bet)
            MockHandActions.fold(3),         // Hero folds to 2nd raise
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
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0),
            MockHandActions.call(3, 12.0),
            MockHandActions.check(3, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isFalse);
          expect(StatsCalculator.hadCbetOpportunity(actions, 4), isTrue);
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
            MockHandActions.bet(4, 8.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
          expect(StatsCalculator.didCbet(actions, 3), isFalse);
        });

        test('returns false when hero raises pre then raises on flop (raise is not c-bet)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.call(4, 6.0),
            MockHandActions.bet(4, 8.0, street: 'flop'),
            MockHandActions.raise(3, 24.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCbetOpportunity(actions, 3), isTrue);
          expect(StatsCalculator.didCbet(actions, 3), isFalse);
        });

        test('handles multiway pot c-bet opportunity correctly', () {
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
          ];
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
            MockHandActions.call(3, 2.0, position: 'UTG'),
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
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3, position: 'UTG'),
            MockHandActions.fold(4, position: 'MP'),
            MockHandActions.fold(5, position: 'CO'),
            MockHandActions.fold(6, position: 'BTN'),
            MockHandActions.fold(1, position: 'SB'),
          ];

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
            MockHandActions.raise(1, 4.0, position: 'SB'),
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
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(3, 6.0, position: 'UTG'),
            MockHandActions.call(2, 4.0, position: 'BB'),
            MockHandActions.fold(1, position: 'SB'),
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(3, 8.0, street: 'flop'),
            MockHandActions.raise(2, 24.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 2), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 2), isTrue);
        });

        test('check-raise works in 3-way pot', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(6, 6.0, position: 'BTN'),
            MockHandActions.call(1, 5.0, position: 'SB'),
            MockHandActions.call(2, 4.0, position: 'BB'),
            MockHandActions.check(1, street: 'flop'),
            MockHandActions.check(2, street: 'flop'),
            MockHandActions.bet(6, 10.0, street: 'flop'),
            MockHandActions.raise(1, 30.0, street: 'flop'),
          ];

          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 1), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 1), isTrue);
          expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 2), isTrue);
          expect(StatsCalculator.didCheckRaiseFlop(actions, 2), isFalse);
        });

        test('in position player cannot check-raise (they act last)', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.raise(6, 6.0, position: 'BTN'),
            MockHandActions.fold(1),
            MockHandActions.call(2, 4.0, position: 'BB'),
            MockHandActions.bet(2, 8.0, street: 'flop'),
            MockHandActions.raise(6, 24.0, street: 'flop'),
          ];

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
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.fold(4),
            MockHandActions.fold(5),
            MockHandActions.fold(6),
            MockHandActions.fold(1),
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

      group('findBigBlindSeat', () {
        test('returns BB seat from blind posting action', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3),
          ];

          expect(StatsCalculator.findBigBlindSeat(actions), 2);
        });

        test('returns BB seat from position field', () {
          final actions = [
            {'player': 5, 'action': 'check', 'playerPosition': 'BB'},
          ];

          expect(StatsCalculator.findBigBlindSeat(actions), 5);
        });

        test('returns null when no BB found', () {
          final actions = [
            MockHandActions.fold(3),
          ];

          expect(StatsCalculator.findBigBlindSeat(actions), isNull);
        });
      });
    });

    group('Blind Defend', () {
      // ---- isSmallBlind / findSmallBlindSeat (mirror isBigBlind / findBigBlindSeat) ----

      group('isSmallBlind', () {
        test('returns true when player posts small blind', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isSmallBlind(actions, 1), isTrue);
        });

        test('returns true when player has SB position', () {
          final actions = [
            {'player': 1, 'action': 'fold', 'playerPosition': 'SB'},
          ];

          expect(StatsCalculator.isSmallBlind(actions, 1), isTrue);
        });

        test('returns false when player is BB', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isSmallBlind(actions, 2), isFalse);
        });

        test('returns false when different player is SB', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
          ];

          expect(StatsCalculator.isSmallBlind(actions, 3), isFalse);
        });
      });

      group('findSmallBlindSeat', () {
        test('returns SB seat from blind posting action', () {
          final actions = [
            MockHandActions.smallBlind(1, 1),
            MockHandActions.bigBlind(2, 2),
            MockHandActions.fold(3),
          ];

          expect(StatsCalculator.findSmallBlindSeat(actions), 1);
        });

        test('returns SB seat from position field', () {
          final actions = [
            {'player': 5, 'action': 'fold', 'playerPosition': 'SB'},
          ];

          expect(StatsCalculator.findSmallBlindSeat(actions), 5);
        });

        test('returns null when no SB found', () {
          final actions = [
            MockHandActions.fold(3),
          ];

          expect(StatsCalculator.findSmallBlindSeat(actions), isNull);
        });
      });

      // ---- hadBlindDefendOpportunity / didBlindDefend ----

      test('BB facing open-raise, calls — opportunity=true, defend=true', () {
        // 6-max: SB=1, BB=2, UTG=3 opens, folds around, BB calls
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.call(2, 4.0, position: 'BB'),
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 2), isTrue);
      });

      test('BB facing open-raise, folds — opportunity=true, defend=false', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.fold(2, position: 'BB'),
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 2), isFalse);
      });

      test('BB facing open-raise, 3-bets — opportunity=true, defend=true', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.raise(2, 18.0, position: 'BB'), // 3-bet = defend
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 2), isTrue);
      });

      test('SB facing open-raise, calls — opportunity=true, defend=true', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.call(1, 5.0, position: 'SB'),
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 1), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 1), isTrue);
      });

      test('SB facing open-raise, folds — opportunity=true, defend=false', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 1), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 1), isFalse);
      });

      test('BB in walk hand (no raise) — opportunity=false', () {
        final actions = MockHandActions.walkHand(playerCount: 6);

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isFalse);
        expect(StatsCalculator.didBlindDefend(actions, 2), isFalse);
      });

      test('BB facing limp only (no raise) — opportunity=false', () {
        // UTG limps, everyone else folds, BB checks
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.call(3, 2.0, position: 'UTG'), // limp (call, not raise)
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.check(2, position: 'BB'),
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isFalse);
        expect(StatsCalculator.didBlindDefend(actions, 2), isFalse);
      });

      test('CO facing raise (not blind) — opportunity=false', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
        ];

        // Seat 5 (CO) is NOT in a blind position
        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 5), isFalse);
        expect(StatsCalculator.didBlindDefend(actions, 5), isFalse);
      });

      test('BB facing open-raise + 3-bet from SB — BB opportunity=true', () {
        // UTG opens, SB 3-bets, BB still has opportunity (faced a raise)
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.raise(3, 6.0, position: 'UTG'),   // open
          MockHandActions.fold(4, position: 'MP'),
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.raise(1, 18.0, position: 'SB'),   // SB 3-bets
          MockHandActions.call(2, 16.0, position: 'BB'),     // BB calls
        ];

        expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isTrue);
        expect(StatsCalculator.didBlindDefend(actions, 2), isTrue);
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
        expect(StatsCalculator.findBigBlindSeat(emptyActions), isNull);
      });

      test('handles missing street field', () {
        final actions = [
          {'player': 1, 'action': 'raise', 'amount': 6.0},
          {'player': 2, 'action': 'call', 'amount': 6.0},
        ];

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
          {'player': 3, 'action': 'raise', 'street': 'preflop', 'amount': 50.0},
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 3), isTrue);
      });

      test('handles player seat that does not exist in actions', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 99), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 99), isFalse);
      });

      test('all-in as 3rd raise is detected as 3-bet', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),   // 1st raise
          MockHandActions.raise(4, 18.0),  // 2nd raise
          {'player': 5, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 3rd = 3-bet
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);
      });

      test('all-in as open should NOT give 3-bet opportunity (only 1 raise)', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 1st raise
          MockHandActions.fold(4),
        ];

        // Only 1 raise happened, so no 3-bet opportunity
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isFalse);
      });

      test('all-in on flop should count for c-bet if last preflop aggressor', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
          MockHandActions.call(4, 6.0),
          {'player': 4, 'action': 'check', 'street': 'flop'},
          {'player': 3, 'action': 'all-in', 'street': 'flop', 'amount': 50.0},
        ];

        expect(StatsCalculator.didCbet(actions, 3), isTrue);
      });

      test('handles bet vs raise distinction on flop', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
          MockHandActions.call(4, 6.0),
          MockHandActions.bet(3, 10.0, street: 'flop'),
          MockHandActions.raise(4, 30.0, street: 'flop'),
        ];

        expect(StatsCalculator.didCbet(actions, 3), isTrue);
      });

      test('multiple players with 3-bet opportunity after 2 raises', () {
        // P3 opens (1st), P4 raises (2nd) — everyone after has 3-bet opportunity
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0, position: 'UTG'),  // 1st raise
          MockHandActions.raise(4, 18.0, position: 'MP'),  // 2nd raise
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.fold(2, position: 'BB'),
        ];

        // P3 only saw 1 raise by others
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        // P4 is the 2nd raiser, saw only 1 raise by others
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isFalse);
        // P5, P6, P1, P2 all saw 2 raises by others — they had 3-bet opportunity
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 5), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 6), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 1), isTrue);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 2), isTrue);

        // None of them 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse);
        expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse);
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
          MockHandActions.raise(3, 30.0, street: 'turn'),
        ];

        expect(StatsCalculator.hadCheckRaiseFlopOpportunity(actions, 3), isFalse);
        expect(StatsCalculator.didCheckRaiseFlop(actions, 3), isFalse);
      });

      test('heads up walk scenario', () {
        final actions = [
          MockHandActions.smallBlind(1, 1),
          MockHandActions.bigBlind(2, 2),
          MockHandActions.fold(1),
        ];

        expect(StatsCalculator.isWalkHand(actions), isTrue);
        expect(StatsCalculator.isBigBlind(actions, 2), isTrue);
        expect(StatsCalculator.isBigBlind(actions, 1), isFalse);
        expect(StatsCalculator.findBigBlindSeat(actions), 2);
      });
    });
  });
}
