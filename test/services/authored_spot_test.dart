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
}
