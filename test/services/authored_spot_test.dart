import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/data/authored_spots_data.dart';
import 'package:poker_logger/models/authored_spot.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/authored_spot_grader.dart';

void main() {
  group('Today authored spot (99 on T94)', () {
    final spot = todayAuthoredSpot;

    test('is the 99 hero spot with 2 decisions', () {
      expect(spot.heroHandClass, '99');
      expect(spot.heroCards, ['9♠', '9♥']);
      expect(spot.decisions.length, 2);
      expect(spot.decisions[0].street, AuthoredStreet.preflop);
      expect(spot.decisions[1].street, AuthoredStreet.flop);
      expect(spot.decisions[1].board, ['10♠', '9♣', '4♦']);
    });

    test('decision 1: CALL is BEST; FOLD is a leak (99 never folds)', () {
      final d = spot.decisions[0];
      final call = AuthoredSpotGrader.grade(d, '99', AuthoredAction.call);
      final fold = AuthoredSpotGrader.grade(d, '99', AuthoredAction.fold);
      final raise = AuthoredSpotGrader.grade(d, '99', AuthoredAction.raise);
      expect(call.grade, DrillGrade.correct); // 83% → BEST
      // With the full solver split, 99 never folds (0%) → a hard leak.
      expect(fold.grade, DrillGrade.mistake);
      // 99 4-bets 17% — a legit mix → OK.
      expect(raise.grade, DrillGrade.ok);
    });

    test('full split: AA 4-bets, AKo jams (allin), neither folds', () {
      final d = spot.decisions[0];
      // AA raises (4-bet) 100% → BEST.
      expect(AuthoredSpotGrader.grade(d, 'AA', AuthoredAction.raise).grade,
          DrillGrade.correct);
      expect(AuthoredSpotGrader.grade(d, 'AA', AuthoredAction.fold).grade,
          DrillGrade.mistake);
      // AKo jams (all-in) 72% → BEST is all-in.
      expect(AuthoredSpotGrader.grade(d, 'AKo', AuthoredAction.allin).grade,
          DrillGrade.correct);
    });

    test('decision 2: check-RAISE is BEST (99 raises 87.5%)', () {
      final d = spot.decisions[1];
      final raise = AuthoredSpotGrader.grade(d, '99', AuthoredAction.raise);
      expect(raise.grade, DrillGrade.correct);
    });
  });

  group('Variant hands', () {
    test('KQs is a bluff check-raise (94%) → BEST on the flop', () {
      final spot = authoredSpotVariants.firstWhere((s) => s.heroHandClass == 'KQs');
      final raise =
          AuthoredSpotGrader.grade(spot.decisions[1], 'KQs', AuthoredAction.raise);
      expect(raise.grade, DrillGrade.correct);
    });

    test('all variants keep hero cards off the board', () {
      const board = {'10♠', '9♣', '4♦'};
      for (final s in authoredSpotVariants) {
        for (final c in s.heroCards) {
          expect(board.contains(c), isFalse,
              reason: '${s.heroHandClass} uses board card $c');
        }
      }
    });
  });

  group('Frequency bands', () {
    final d = todayAuthoredSpot.decisions[0];
    test('mix (15–65%) grades OK', () {
      // QQ calls 15.4% vs the 3-bet in this node → a legit mix → OK.
      final g = AuthoredSpotGrader.grade(d, 'QQ', AuthoredAction.call);
      expect(g.grade, DrillGrade.ok);
    });
  });

  group('Range-standard softening', () {
    // A flop node where the RANGE bets ~78% but one hand (TT) bets only 12%
    // and checks 88%. Betting is range-standard, so TT's bet must soften from
    // LEAK to GOOD; folding a hand that wants to continue must still be a LEAK.
    AuthoredDecision flop({
      required Map<String, double> bet,
      required Map<String, double> check,
      Map<String, double> fold = const {},
    }) =>
        AuthoredDecision(
          street: AuthoredStreet.flop,
          board: const ['J♦', '8♥', '8♦'],
          prompt: 'flop',
          options: const [
            AuthoredAction.fold,
            AuthoredAction.check,
            AuthoredAction.raise,
          ],
          best: AuthoredAction.check,
          potBB: 10,
          toCallBB: 0,
          freq: {
            AuthoredAction.raise: bet,
            AuthoredAction.check: check,
            if (fold.isNotEmpty) AuthoredAction.fold: fold,
          },
        );

    // Range bets heavily (AK/AQ/KQ all ~1.0 bet); TT is the check-preferring
    // exception (bet 0.12 / check 0.88).
    final d = flop(
      bet: const {'AKs': 1.0, 'AQs': 1.0, 'KQs': 1.0, 'TT': 0.12},
      check: const {'TT': 0.88},
    );

    test('range-standard low-freq action: TT bet → GOOD, not LEAK', () {
      final g = AuthoredSpotGrader.grade(d, 'TT', AuthoredAction.raise);
      expect(g.grade, DrillGrade.ok);
      expect(g.explanation.toLowerCase(), contains('standard'));
    });

    test('the dominant line is still BEST', () {
      final g = AuthoredSpotGrader.grade(d, 'TT', AuthoredAction.check);
      expect(g.grade, DrillGrade.correct);
    });

    test('fold is never softened, even when the range folds a lot', () {
      // Range folds 80% here; a hand that wants to continue still leaks by
      // folding.
      final foldHeavy = flop(
        bet: const {'TT': 0.9},
        check: const {},
        fold: const {'72o': 1.0, '83o': 1.0, '94o': 1.0, '62o': 1.0, 'TT': 0.0},
      );
      final g =
          AuthoredSpotGrader.grade(foldHeavy, 'TT', AuthoredAction.fold);
      expect(g.grade, DrillGrade.mistake);
    });

    test('a truly range-avoided action still LEAKs', () {
      // Nobody bets here (range checks ~100%); TT betting 5% is a real leak.
      final checkHeavy = flop(
        bet: const {'TT': 0.05},
        check: const {'AKs': 1.0, 'AQs': 1.0, 'KQs': 1.0, 'TT': 0.95},
      );
      final g =
          AuthoredSpotGrader.grade(checkHeavy, 'TT', AuthoredAction.raise);
      expect(g.grade, DrillGrade.mistake);
    });
  });
}
