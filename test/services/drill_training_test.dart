import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/models/opponent_stats.dart';
import 'package:poker_logger/services/drill_engine.dart';
import 'package:poker_logger/services/drill_grader.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';
import 'package:poker_logger/services/drill_hand_strength.dart';
import 'package:poker_logger/services/drill_opponent_profiler.dart';

DrillVillainProfile profile({
  String name = 'Villain',
  double vpip = 24,
  double pfr = 17,
  double threeBet = 7,
  double fold3bet = 55,
  double aggression = 50,
  int hands = 200,
  String archetype = 'Regular',
}) {
  return DrillVillainProfile(
    opponentId: 'opp_$name',
    name: name,
    handsObserved: hands,
    vpip: vpip,
    pfr: pfr,
    threeBet: threeBet,
    fold3bet: fold3bet,
    aggression: aggression,
    archetype: archetype,
  );
}

/// Profile that always folds when not in the blinds (and checks its BB).
DrillVillainProfile folderProfile(String name) => profile(
    name: name, vpip: 0, pfr: 0, threeBet: 0, fold3bet: 100, hands: 500);

List<DrillSeat> buildSeats(int count, int heroSeat,
    {DrillVillainProfile Function(int seat)? villain}) {
  return [
    for (int s = 1; s <= count; s++)
      DrillSeat(
        seatNumber: s,
        isHero: s == heroSeat,
        profile: s == heroSeat
            ? null
            : (villain?.call(s) ?? DrillVillainProfile.prior),
      )
  ];
}

DrillSeatRef seatRef(
  DrillVillainProfile p, {
  String pos = 'BB',
  bool blind = true,
  bool directLeft = false,
}) =>
    DrillSeatRef(
      profile: p,
      positionGroup: pos,
      isBlind: blind,
      isDirectLeft: directLeft,
    );

DrillDecisionContext ctx({
  required String handClass,
  required String positionGroup,
  double stackBB = 100,
  DrillScenario scenario = DrillScenario.unopened,
  DrillVillainProfile? opener,
  List<DrillVillainProfile> limpers = const [],
  List<DrillVillainProfile> playersBehind = const [],
  List<DrillSeatRef> behindDetail = const [],
  double toCallBB = 0,
  double currentBetBB = 1,
  double potBB = 1.5,
  int raisesBeforeHero = 0,
}) {
  return DrillDecisionContext(
    handClass: handClass,
    positionGroup: positionGroup,
    stackBB: stackBB,
    scenario: scenario,
    opener: opener,
    limpers: limpers,
    playersBehind: playersBehind,
    behindDetail: behindDetail,
    toCallBB: toCallBB,
    currentBetBB: currentBetBB,
    potBB: potBB,
    raisesBeforeHero: raisesBeforeHero,
  );
}

void main() {
  group('DrillHandStrength', () {
    test('builds all 169 hand classes', () {
      expect(DrillHandStrength.allHandClasses.length, 169);
    });

    test('AA is the strongest class', () {
      expect(DrillHandStrength.topPercent('AA'), lessThan(1.0));
      for (final hc in DrillHandStrength.allHandClasses) {
        expect(DrillHandStrength.topPercent('AA'),
            lessThanOrEqualTo(DrillHandStrength.topPercent(hc)));
      }
    });

    test('72o is near the bottom', () {
      expect(DrillHandStrength.topPercent('72o'), greaterThan(85));
    });

    test('relative ordering is sane', () {
      expect(DrillHandStrength.topPercent('KK'),
          lessThan(DrillHandStrength.topPercent('QQ')));
      expect(DrillHandStrength.topPercent('AKs'),
          lessThan(DrillHandStrength.topPercent('AKo')));
      expect(DrillHandStrength.topPercent('AKo'),
          lessThan(DrillHandStrength.topPercent('A9o')));
      expect(DrillHandStrength.topPercent('JJ'),
          lessThan(DrillHandStrength.topPercent('55')));
    });

    test('weakest class reaches 100%', () {
      double maxPercent = 0;
      for (final hc in DrillHandStrength.allHandClasses) {
        maxPercent = max(maxPercent, DrillHandStrength.topPercent(hc));
      }
      expect(maxPercent, closeTo(100, 0.001));
    });

    test('unknown input never counts as strong', () {
      expect(DrillHandStrength.topPercent('XYZ'), 100.0);
      expect(DrillHandStrength.inTopPercent('XYZ', 50), isFalse);
    });
  });

  group('DrillOpponentProfiler', () {
    test('small samples shrink toward the prior', () {
      // 10 eligible hands of 100% VPIP must not produce a 100 VPIP bot
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 10,
        vpipCount: 10,
        pfrCount: 0,
      );
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.vpip, lessThan(60));
      expect(p.vpip, greaterThan(DrillVillainProfile.prior.vpip));
    });

    test('large samples dominate the prior', () {
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 400,
        vpipCount: 200, // 50%
        pfrCount: 20, // 5%
      );
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.vpip, greaterThan(45));
      expect(p.pfr, lessThan(8));
      expect(p.limpRate, greaterThan(25)); // big VPIP-PFR gap → heavy limper
    });

    test('no 3-bet opportunities falls back to prior 3-bet', () {
      final stats = OpponentStats(opponentId: 'x', handsPlayed: 100);
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.threeBet, DrillVillainProfile.prior.threeBet);
    });
  });

  group('DrillEngine', () {
    test('posts blinds and starts with 1.5BB pot', () {
      final engine = DrillEngine(
          seats: buildSeats(6, 3), stackBB: 100, rng: Random(42));
      final update = engine.startHand();
      final posts =
          update.newEvents.where((e) => e.action.startsWith('posts')).toList();
      expect(posts.length, 2);
      expect(posts[0].action, 'posts SB');
      expect(posts[1].action, 'posts BB');
    });

    test('is deterministic for a fixed seed', () {
      List<String> run(int seed) {
        final engine = DrillEngine(
            seats: buildSeats(6, 1), stackBB: 100, rng: Random(seed));
        final update = engine.startHand();
        return update.newEvents.map((e) => '${e.seat}:${e.action}').toList();
      }

      expect(run(7), run(7));
    });

    test('every hand terminates (hero auto-folds)', () {
      final engine = DrillEngine(
          seats: buildSeats(7, 4), stackBB: 100, rng: Random(1));
      for (int i = 0; i < 200; i++) {
        var update = engine.startHand();
        int guard = 0;
        while (update.awaitingHero && guard++ < 10) {
          update = engine.applyHeroAction(
              update.heroTurn!.canCheck ? 'check' : 'fold');
        }
        expect(update.handComplete, isTrue,
            reason: 'hand ${engine.handNumber} did not complete');
      }
    });

    test('everyone folding to hero in the BB is a walk with no decision', () {
      final engine = DrillEngine(
        seats: buildSeats(4, 2, villain: (s) => folderProfile('F$s')),
        stackBB: 100,
        rng: Random(3),
      );
      bool sawWalk = false;
      for (int i = 0; i < 8 && !sawWalk; i++) {
        final update = engine.startHand();
        if (update.heroWalked) {
          sawWalk = true;
          expect(update.awaitingHero, isFalse);
          expect(update.handComplete, isTrue);
          expect(update.heroWonUncontested, isTrue);
        } else if (update.awaitingHero) {
          engine.applyHeroAction(
              update.heroTurn!.canCheck ? 'check' : 'fold');
        }
      }
      expect(sawWalk, isTrue,
          reason: 'button rotates every hand, hero must hit the BB');
    });

    test('hero raise vs folders wins the pot uncontested', () {
      final engine = DrillEngine(
        seats: buildSeats(5, 1, villain: (s) => folderProfile('F$s')),
        stackBB: 100,
        rng: Random(11),
      );
      for (int i = 0; i < 10; i++) {
        var update = engine.startHand();
        if (!update.awaitingHero) continue; // walk hand
        update = engine.applyHeroAction('raise', raiseToBB: 2.5);
        if (update.awaitingHero) {
          // BB folder never re-raises, so this shouldn't happen
          fail('folder villain re-raised');
        }
        expect(update.handComplete, isTrue);
        expect(update.heroWonUncontested, isTrue);
        expect(update.grade, isNotNull);
        return;
      }
      fail('hero never got a decision in 10 hands');
    });

    test('hero cards are always two distinct cards with a valid class', () {
      final engine = DrillEngine(
          seats: buildSeats(6, 2), stackBB: 100, rng: Random(5));
      for (int i = 0; i < 50; i++) {
        var update = engine.startHand();
        expect(engine.heroCards.length, 2);
        expect(engine.heroCards[0], isNot(engine.heroCards[1]));
        expect(DrillHandStrength.allHandClasses,
            contains(engine.heroHandClass));
        int guard = 0;
        while (update.awaitingHero && guard++ < 10) {
          update = engine.applyHeroAction(
              update.heroTurn!.canCheck ? 'check' : 'fold');
        }
      }
    });

    test('limpy villains produce vsLimpers decision spots', () {
      final limper = profile(
          name: 'Limpy', vpip: 55, pfr: 4, threeBet: 2, hands: 300);
      final engine = DrillEngine(
        seats: buildSeats(6, 6, villain: (_) => limper),
        stackBB: 100,
        rng: Random(9),
      );
      bool sawLimpSpot = false;
      for (int i = 0; i < 60 && !sawLimpSpot; i++) {
        var update = engine.startHand();
        int guard = 0;
        while (update.awaitingHero && guard++ < 10) {
          if (update.heroTurn!.scenario == DrillScenario.vsLimpers) {
            sawLimpSpot = true;
          }
          update = engine.applyHeroAction(
              update.heroTurn!.canCheck ? 'check' : 'fold');
        }
      }
      expect(sawLimpSpot, isTrue);
    });

    test('handClassFor canonicalizes 10s and suits', () {
      expect(DrillEngine.handClassFor('A♠', 'K♠'), 'AKs');
      expect(DrillEngine.handClassFor('K♥', 'A♠'), 'AKo');
      expect(DrillEngine.handClassFor('10♦', '10♣'), 'TT');
      expect(DrillEngine.handClassFor('2♣', 'A♣'), 'A2s');
    });
  });

  group('DrillGrader', () {
    test('open-folding trash in EP is correct', () {
      final r = DrillGrader.grade(
          ctx(handClass: '72o', positionGroup: 'EP'), 'fold');
      expect(r.grade, DrillGrade.correct);
      expect(r.recommendedAction, 'fold');
    });

    test('open-raising trash in EP is a mistake', () {
      final r = DrillGrader.grade(
          ctx(handClass: '72o', positionGroup: 'EP'), 'raise',
          raiseToBB: 2.5);
      expect(r.grade, DrillGrade.mistake);
    });

    test('opening AA anywhere is correct', () {
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
        final r = DrillGrader.grade(
            ctx(handClass: 'AA', positionGroup: pos), 'raise',
            raiseToBB: 2.5);
        expect(r.grade, DrillGrade.correct, reason: pos);
      }
    });

    test('oversized open with AA gets a sizing note, not a mistake', () {
      final r = DrillGrader.grade(
          ctx(handClass: 'AA', positionGroup: 'BTN'), 'raise',
          raiseToBB: 8);
      expect(r.grade, DrillGrade.ok);
      expect(r.explanation, contains('sizing'));
    });

    test('jam sizing is not penalized', () {
      final r = DrillGrader.grade(
          ctx(handClass: 'AA', positionGroup: 'BTN', stackBB: 20), 'raise',
          raiseToBB: 20);
      expect(r.grade, DrillGrade.correct);
    });

    test('exploit note names a foldy opener when 3-betting', () {
      final foldy = profile(name: 'FoldyFred', fold3bet: 75, hands: 250);
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AA',
          positionGroup: 'BTN',
          scenario: DrillScenario.vsRaise,
          opener: foldy,
          toCallBB: 2.5,
          currentBetBB: 2.5,
          potBB: 4,
          raisesBeforeHero: 1,
        ),
        'raise',
        raiseToBB: 7.5,
      );
      expect(r.grade, DrillGrade.correct);
      expect(r.explanation, contains('FoldyFred'));
      expect(r.explanation, contains('3-bet'));
    });

    test('nitty opener tightens the calling range', () {
      final nit = profile(name: 'NittyNed', vpip: 12, pfr: 10, hands: 300);
      final r = DrillGrader.grade(
        ctx(
          handClass: '72o',
          positionGroup: 'BTN',
          scenario: DrillScenario.vsRaise,
          opener: nit,
          toCallBB: 2.5,
          currentBetBB: 2.5,
          potBB: 4,
          raisesBeforeHero: 1,
        ),
        'fold',
      );
      expect(r.grade, DrillGrade.correct);
      expect(r.explanation, contains('NittyNed'));
    });

    test('short stack vs raise recommends jam-or-fold language', () {
      final r = DrillGrader.grade(
        ctx(
          handClass: 'T9s',
          positionGroup: 'BTN',
          stackBB: 20,
          scenario: DrillScenario.vsRaise,
          opener: profile(),
          toCallBB: 2.5,
          currentBetBB: 2.5,
          potBB: 4,
          raisesBeforeHero: 1,
        ),
        'call',
      );
      expect(r.explanation, contains('jam'));
    });

    test('BB checking junk behind limpers is correct, folding is a mistake',
        () {
      final limpCtx = ctx(
        handClass: '72o',
        positionGroup: 'BB',
        scenario: DrillScenario.vsLimpers,
        limpers: [profile(name: 'Limpy', vpip: 50, pfr: 5)],
        toCallBB: 0,
        potBB: 2.5,
      );
      expect(DrillGrader.grade(limpCtx, 'check').grade, DrillGrade.correct);
      expect(DrillGrader.grade(limpCtx, 'fold').grade, DrillGrade.mistake);
    });

    test('iso-raising premiums over a loose-passive limper is correct '
        'and names the limper', () {
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AQs',
          positionGroup: 'BTN',
          scenario: DrillScenario.vsLimpers,
          limpers: [
            profile(name: 'LoosePassiveLarry', vpip: 48, pfr: 6, hands: 220)
          ],
          toCallBB: 1,
          currentBetBB: 1,
          potBB: 2.5,
        ),
        'raise',
        raiseToBB: 4,
      );
      expect(r.grade, DrillGrade.correct);
      expect(r.explanation, contains('LoosePassiveLarry'));
    });

    test('folding to a 3-bet with a weak open vs a tight 3-bettor is correct',
        () {
      final tight =
          profile(name: 'TightTed', threeBet: 3, hands: 300);
      final r = DrillGrader.grade(
        ctx(
          handClass: '72o',
          positionGroup: 'CO',
          scenario: DrillScenario.vs3betAsAggressor,
          opener: tight,
          toCallBB: 5,
          currentBetBB: 7.5,
          potBB: 11.5,
          raisesBeforeHero: 2,
        ),
        'fold',
      );
      expect(r.grade, DrillGrade.correct);
      expect(r.explanation, contains('TightTed'));
    });

    test('4-betting AA vs a 3-bet is correct', () {
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AA',
          positionGroup: 'CO',
          scenario: DrillScenario.vs3betAsAggressor,
          opener: profile(),
          toCallBB: 5,
          currentBetBB: 7.5,
          potBB: 11.5,
          raisesBeforeHero: 2,
        ),
        'raise',
        raiseToBB: 18,
      );
      expect(r.grade, DrillGrade.correct);
    });

    test('cold-calling a 3-bet with junk is a mistake', () {
      final r = DrillGrader.grade(
        ctx(
          handClass: 'J4o',
          positionGroup: 'BTN',
          scenario: DrillScenario.vs3betCold,
          opener: profile(),
          toCallBB: 7.5,
          currentBetBB: 7.5,
          potBB: 12,
          raisesBeforeHero: 2,
        ),
        'call',
      );
      expect(r.grade, DrillGrade.mistake);
    });

    test('aggro 3-bettor behind tightens opens and is named', () {
      final aggro = profile(name: 'AggroAnna', threeBet: 14, hands: 260);
      // A marginal button open: with a 14% 3-bettor behind, the range
      // tightens by 4 points (42 → 38). Pick a hand inside the close band
      // of neither boundary: use a clearly-in hand and check the note text.
      final r = DrillGrader.grade(
        ctx(
          handClass: 'KQs',
          positionGroup: 'BTN',
          playersBehind: [aggro],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      expect(r.grade, DrillGrade.correct);
      expect(r.explanation, contains('AggroAnna'));
    });

    test('grade result exposes the hand percentile and range boundary', () {
      final r = DrillGrader.grade(
          ctx(handClass: 'AA', positionGroup: 'BTN'), 'raise',
          raiseToBB: 2.5);
      expect(r.handTopPercent, lessThan(1.0)); // AA is the top combo
      expect(r.rangePercent, greaterThan(0));
    });
  });

  group('DrillGrader position-aware exploits', () {
    test('tight players in the blinds widen the BTN steal range and are named',
        () {
      final nit = profile(name: 'NittyTom', vpip: 12, pfr: 9, hands: 220);
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AA',
          positionGroup: 'BTN',
          behindDetail: [
            seatRef(nit, pos: 'SB'),
            seatRef(nit, pos: 'BB'),
          ],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      // Default BTN open is top 42%; tight blinds must widen it well past that
      expect(r.rangePercent, greaterThan(50));
      expect(r.explanation, contains('NittyTom'));
      expect(r.explanation.toLowerCase(), contains('steal'));
    });

    test('a marginal BTN hand becomes an open vs passive blinds', () {
      // A hand just outside the GTO BTN open but inside a widened range.
      final gtoSet = DrillGtoCharts.openRange('BTN');
      final marginal = DrillGtoCharts.widen(gtoSet, 12)
          .firstWhere((h) => !gtoSet.contains(h));
      final nit = profile(name: 'Nit', vpip: 10, pfr: 8, hands: 300);
      final passive = ctx(
        handClass: marginal,
        positionGroup: 'BTN',
        behindDetail: [seatRef(nit, pos: 'SB'), seatRef(nit, pos: 'BB')],
      );
      expect(DrillGrader.grade(passive, 'raise', raiseToBB: 2.5).grade,
          DrillGrade.correct);
      // The same hand vs a default (generic) table should be a fold
      final neutral = ctx(handClass: marginal, positionGroup: 'BTN');
      expect(DrillGrader.grade(neutral, 'fold').recommendedAction, 'fold');
    });

    test('aggressive 3-bettor on the direct left tightens opens and is named',
        () {
      final anna = profile(name: 'AggroAnna', threeBet: 16, hands: 240);
      final r = DrillGrader.grade(
        ctx(
          handClass: 'A5s',
          positionGroup: 'CO',
          behindDetail: [
            seatRef(anna, pos: 'BTN', blind: false, directLeft: true),
          ],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      // CO default is top 26%; a 16% 3-bettor on the direct left cuts it
      expect(r.rangePercent, lessThan(24));
      expect(r.explanation, contains('AggroAnna'));
      expect(r.explanation, contains('direct left'));
    });

    test('a wide-defending blind tightens the steal toward value', () {
      final station = profile(name: 'CallingCal', vpip: 45, pfr: 8, hands: 260);
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AA',
          positionGroup: 'BTN',
          behindDetail: [seatRef(station, pos: 'BB')],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      expect(r.explanation, contains('CallingCal'));
      expect(r.explanation.toLowerCase(), contains('defend'));
    });

    test('unopened feedback always references the lineup, never bare GTO', () {
      // Middling blinds (no exploit rule fires) still get a lineup note.
      final reg = profile(name: 'SteadyEddie', vpip: 28, pfr: 20, hands: 300);
      final r = DrillGrader.grade(
        ctx(
          handClass: 'AA',
          positionGroup: 'BTN',
          behindDetail: [seatRef(reg, pos: 'BB')],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      expect(r.explanation, contains('SteadyEddie'));
    });
  });

  group('DrillGrader dual GTO/exploit evaluation', () {
    test('every verdict carries both a GTO and an exploit line', () {
      final r = DrillGrader.grade(
          ctx(handClass: 'AA', positionGroup: 'BTN'), 'raise',
          raiseToBB: 2.5);
      expect(r.gtoAction, isNotEmpty);
      expect(r.exploitAction, isNotEmpty);
      expect(r.gtoReason, isNotEmpty);
      expect(r.exploitReason, isNotEmpty);
    });

    test('lines agree (and are flagged) when there is no read to exploit', () {
      final r = DrillGrader.grade(
          ctx(handClass: 'AA', positionGroup: 'BTN'), 'raise',
          raiseToBB: 2.5);
      expect(r.gtoAction, 'raise');
      expect(r.exploitAction, 'raise');
      expect(r.linesAgree, isTrue);
    });

    test('lines diverge: GTO fold but exploit open vs tight blinds', () {
      final gtoSet = DrillGtoCharts.openRange('BTN');
      final marginal = DrillGtoCharts.widen(gtoSet, 12)
          .firstWhere((h) => !gtoSet.contains(h));
      final nit = profile(name: 'Nit', vpip: 10, pfr: 8, hands: 300);
      final r = DrillGrader.grade(
        ctx(
          handClass: marginal,
          positionGroup: 'BTN',
          behindDetail: [seatRef(nit, pos: 'SB'), seatRef(nit, pos: 'BB')],
        ),
        'raise',
        raiseToBB: 2.5,
      );
      expect(r.gtoAction, 'fold');
      expect(r.exploitAction, 'raise');
      expect(r.linesAgree, isFalse);
      // Graded against the exploit line, raising is correct here
      expect(r.grade, DrillGrade.correct);
      expect(r.gtoRangePercent, lessThan(r.exploitRangePercent));
    });

    test('vs an open the GTO line is stack/position-only, exploit adds reads',
        () {
      // A hand outside the GTO 3-bet range (top 5%) but inside FoldyFred's
      // widened one (top 11%): GTO flats, exploit 3-bets.
      final hand = DrillHandStrength.allHandClasses.firstWhere((h) {
        final t = DrillHandStrength.topPercent(h);
        return t > 6 && t < 10;
      });
      final foldy = profile(name: 'FoldyFred', fold3bet: 78, hands: 250);
      final r = DrillGrader.grade(
        ctx(
          handClass: hand,
          positionGroup: 'BTN',
          scenario: DrillScenario.vsRaise,
          opener: foldy,
          toCallBB: 2.5,
          currentBetBB: 2.5,
          potBB: 4,
          raisesBeforeHero: 1,
        ),
        'raise',
        raiseToBB: 7.5,
      );
      expect(r.gtoAction, 'call'); // GTO continues but doesn't re-raise
      expect(r.exploitAction, 'raise'); // exploit 3-bets the foldy opener
      expect(r.exploitReason, contains('FoldyFred'));
      expect(r.gtoReason.toLowerCase(), contains('gto'));
    });
  });

  group('DrillGrader GTO opening ranges (chart-based)', () {
    test('55 is a GTO open from early position (the reported bug)', () {
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
        final r = DrillGrader.grade(
            ctx(handClass: '55', positionGroup: pos), 'raise',
            raiseToBB: 2.5);
        expect(r.gtoAction, 'raise', reason: '55 should open from $pos');
        expect(r.grade, DrillGrade.correct, reason: '55 open from $pos');
      }
    });

    test('folding 55 from EP is now a mistake (it is an open)', () {
      final r =
          DrillGrader.grade(ctx(handClass: '55', positionGroup: 'EP'), 'fold');
      expect(r.recommendedAction, 'raise');
      expect(r.grade, DrillGrade.mistake);
    });

    test('72o is a GTO fold from every position', () {
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
        final r =
            DrillGrader.grade(ctx(handClass: '72o', positionGroup: pos), 'fold');
        expect(r.gtoAction, 'fold', reason: '72o should fold from $pos');
        expect(r.grade, DrillGrade.correct);
      }
    });

    test('opening a small pair from EP grades correct, not against GTO', () {
      final r = DrillGrader.grade(
          ctx(handClass: '22', positionGroup: 'EP'), 'raise',
          raiseToBB: 2.5);
      expect(r.gtoAction, 'raise');
    });
  });
}
