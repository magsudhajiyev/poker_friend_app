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
      // 3-bet = the 2nd VOLUNTARY raise preflop.
      // Blinds are forced (not raises). 1st voluntary raise = the open,
      // 2nd voluntary raise = 3-bet, 3rd = 4-bet.

      group('didPlayerThreeBet', () {
        test('re-raise over an open IS a 3-bet (headline)', () {
          // P3 opens (1st voluntary raise), P4 re-raises (2nd = 3-bet).
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open (1st raise)
            MockHandActions.raise(4, 18.0),  // 3-bet (2nd raise)
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // 3-bettor
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // opener
        });

        test('the 3rd voluntary raise is a 4-bet, not a 3-bet', () {
          // P3 opens (1st), P4 3-bets (2nd), P5 4-bets (3rd).
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open
            MockHandActions.raise(4, 18.0),  // 3-bet
            MockHandActions.raise(5, 50.0),  // 4-bet
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse); // 4-bet, not 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // opener
        });

        test('opener who re-raises after being 3-bet is 4-betting, not 3-betting', () {
          // P3 opens (1st), P4 3-bets (2nd), P3 4-bets (3rd).
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open
            MockHandActions.raise(4, 18.0),  // 3-bet by P4
            MockHandActions.raise(3, 50.0),  // 4-bet by P3
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // P4 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // P3 4-bet
        });

        test('returns false when the pot is only opened (no re-raise)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open only
            MockHandActions.call(4, 6.0),    // flat call
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero open-raises with no prior raise', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.fold(3),
            MockHandActions.raise(4, 6.0), // hero opens (1st raise)
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero calls the open instead of 3-betting', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),  // open
            MockHandActions.call(4, 6.0),   // hero flats
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false when hero folds to the open', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),  // open
            MockHandActions.fold(4),        // hero folds to open
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isFalse);
        });

        test('returns false for a player who folds after someone else 3-bets', () {
          // P3 opens (1st), P4 3-bets (2nd), P5 folds — P5 did not 3-bet.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.raise(4, 18.0),
            MockHandActions.fold(5),
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse);
        });

        test('ignores non-preflop raises (flop bet-raise is not a preflop 3-bet)', () {
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

        test('all-in as the 2nd voluntary raise IS a 3-bet', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open
            {'player': 4, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 3-bet jam
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);
        });

        test('all-in as the open (1st raise) is NOT a 3-bet', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // open jam
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse);
        });

        test('multiway: MP 3-bets over UTG open, CO 4-bets', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0, position: 'UTG'),   // open (1st)
            MockHandActions.raise(4, 18.0, position: 'MP'),   // 3-bet (2nd)
            MockHandActions.raise(5, 50.0, position: 'CO'),   // 4-bet (3rd)
            MockHandActions.fold(6, position: 'BTN'),
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // MP 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse); // CO 4-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // UTG opener
        });

        test('limp then raise: the first raise over a limp is the open, not a 3-bet', () {
          // UTG limps (a call, not a raise), BTN raises = the OPEN (1st voluntary
          // raise). A limp does not make the raise a 3-bet.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'),   // limp
            MockHandActions.raise(6, 8.0, position: 'BTN'),  // open (1st raise)
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse); // open, not 3-bet
        });

        test('limp, open, re-raise: the re-raise over the open IS the 3-bet', () {
          // UTG limps, BTN raises (open = 1st raise), UTG re-raises (3-bet = 2nd raise).
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0, position: 'UTG'),   // limp
            MockHandActions.raise(6, 8.0, position: 'BTN'),  // open (1st raise)
            MockHandActions.raise(3, 24.0, position: 'UTG'), // 3-bet (2nd raise)
          ];

          expect(StatsCalculator.didPlayerThreeBet(actions, 3), isTrue);  // UTG 3-bet
          expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse); // BTN opened
        });
      });

      group('hadThreeBetOpportunity', () {
        test('player acting after just the open HAD a 3-bet opportunity (cold-3bet spot)', () {
          // P3 opens (1st raise), P4 acts next — could 3-bet.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open (1 raise)
            MockHandActions.fold(4),         // P4 declines
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
        });

        test('taking the 3-bet counts as having the opportunity', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open
            MockHandActions.raise(4, 18.0),  // P4 3-bets
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
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

        test('opener facing a 3-bet is in 4-bet territory, NOT a 3-bet opportunity', () {
          // P3 opens (1st), P4 3-bets (2nd), action back to P3 — 2 raises already,
          // so P3 would be 4-betting, not 3-betting.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open
            MockHandActions.raise(4, 18.0),  // 3-bet
            MockHandActions.fold(3),         // P3 acts after 2 raises (4-bet spot)
          ];

          expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        });
      });
    });

    group('Fold to 3-Bet Detection', () {
      group('facedThreeBet', () {
        test('opener who gets 3-bet faced a 3-bet', () {
          // Hero opens (1st raise), P4 3-bets (2nd raise).
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // hero opens
            MockHandActions.raise(4, 18.0),  // 3-bet
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isTrue);
        });

        test('returns false when hero opens and everyone folds', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),
            MockHandActions.fold(4),
            MockHandActions.fold(5),
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero limps (did not open) then someone raises', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.call(3, 2.0),   // hero limps
            MockHandActions.raise(4, 8.0),  // open by someone else
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when only the hero raised (self re-raise not counted)', () {
          // Only hero ever raises — no opponent 3-bet against them.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // hero opens
            MockHandActions.call(4, 6.0),
          ];

          expect(StatsCalculator.facedThreeBet(actions, 3), isFalse);
        });

        test('returns false when hero never raised', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open by P3
            MockHandActions.raise(4, 18.0),  // 3-bet by P4
          ];

          expect(StatsCalculator.facedThreeBet(actions, 6), isFalse); // P6 never acted/raised
        });
      });

      group('didFoldTo3Bet', () {
        test('returns true when hero opens, faces a 3-bet, then folds', () {
          // Hero opens (1st), P4 3-bets (2nd), hero folds.
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // hero opens
            MockHandActions.raise(4, 18.0),  // 3-bet
            MockHandActions.fold(3),         // hero folds to 3-bet
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isTrue);
        });

        test('returns false when hero faces the 3-bet but calls', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // hero opens
            MockHandActions.raise(4, 18.0),  // 3-bet
            MockHandActions.call(3, 12.0),   // hero calls
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });

        test('returns false when hero faces the 3-bet and 4-bets', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // hero opens
            MockHandActions.raise(4, 18.0),  // 3-bet
            MockHandActions.raise(3, 50.0),  // hero 4-bets
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 3), isFalse);
        });

        test('returns false when hero folds to just the open (no 3-bet)', () {
          final actions = [
            ...MockHandActions.blindsOnly(),
            MockHandActions.raise(3, 6.0),   // open only
            MockHandActions.fold(4),         // hero folds to the open, not a 3-bet
          ];

          expect(StatsCalculator.didFoldTo3Bet(actions, 4), isFalse);
        });

        test('returns false when hero folds preflop with no raise at all', () {
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
        // P1 opens (1st raise), P2 3-bets (2nd raise), P3 4-bets (3rd raise) —
        // regardless of casing on action/street.
        final actions = [
          {'player': 1, 'action': 'RAISE', 'street': 'PREFLOP', 'amount': 6.0},
          {'player': 2, 'action': 'Raise', 'street': 'Preflop', 'amount': 18.0},
          {'player': 3, 'action': 'raise', 'street': 'preflop', 'amount': 50.0},
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 2), isTrue);  // 2nd raise = 3-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // 3rd raise = 4-bet
      });

      test('handles player seat that does not exist in actions', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 99), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 99), isFalse);
      });

      test('all-in as the 2nd voluntary raise is detected as a 3-bet', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),   // open (1st raise)
          {'player': 4, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 3-bet (2nd raise)
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);
      });

      test('all-in as the 3rd voluntary raise is a 4-bet, not a 3-bet', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0),   // open
          MockHandActions.raise(4, 18.0),  // 3-bet
          {'player': 5, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // 4-bet jam
        ];

        expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse); // 4-bet
        expect(StatsCalculator.didPlayerThreeBet(actions, 4), isTrue);  // 3-bet
      });

      test('all-in as the open gives the next player a 3-bet opportunity', () {
        final actions = [
          ...MockHandActions.blindsOnly(),
          {'player': 3, 'action': 'all-in', 'street': 'preflop', 'amount': 100.0}, // open (1st raise)
          MockHandActions.fold(4),
        ];

        // 1 raise (the open) happened → the next player HAD a 3-bet opportunity.
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
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

      test('3-bet opportunity exists only right after the open (1 raise)', () {
        // UTG opens (1st raise), MP 3-bets (2nd raise) — after that it's 4-bet
        // territory, so later players did NOT have a 3-bet opportunity.
        final actions = [
          ...MockHandActions.blindsOnly(),
          MockHandActions.raise(3, 6.0, position: 'UTG'),  // open (1st raise)
          MockHandActions.raise(4, 18.0, position: 'MP'),  // 3-bet (2nd raise)
          MockHandActions.fold(5, position: 'CO'),
          MockHandActions.fold(6, position: 'BTN'),
          MockHandActions.fold(1, position: 'SB'),
          MockHandActions.fold(2, position: 'BB'),
        ];

        // UTG never faced the open before acting → no 3-bet opportunity.
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 3), isFalse);
        // MP acted after exactly 1 raise (the open) → HAD a 3-bet opportunity (took it).
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 4), isTrue);
        // CO/BTN/SB/BB acted after 2 raises (open + 3-bet) → 4-bet spot, NOT a 3-bet opp.
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 5), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 6), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 1), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, 2), isFalse);

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
