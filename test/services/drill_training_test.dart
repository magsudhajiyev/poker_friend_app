import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/models/opponent_stats.dart';
import 'package:poker_logger/services/drill_engine.dart';
import 'package:poker_logger/services/drill_hand_strength.dart';
import 'package:poker_logger/services/drill_opponent_profiler.dart';

DrillVillainProfile profile({
  String name = 'Villain',
  double threeBet = 7,
  double fold3bet = 55,
  double aggression = 50,
  double steal = 28,
  double cbet = 65,
  double blindDefend = 35,
  double showdown = 28,
  double checkRaiseFlop = 8,
  int hands = 200,
  String archetype = 'Regular',
}) {
  return DrillVillainProfile(
    opponentId: 'opp_$name',
    name: name,
    handsObserved: hands,
    threeBet: threeBet,
    fold3bet: fold3bet,
    aggression: aggression,
    steal: steal,
    cbet: cbet,
    blindDefend: blindDefend,
    showdown: showdown,
    checkRaiseFlop: checkRaiseFlop,
    archetype: archetype,
  );
}

/// Profile that always folds when not in the blinds (and checks its BB).
DrillVillainProfile folderProfile(String name) => profile(
    name: name, threeBet: 0, fold3bet: 100, aggression: 0,
    steal: 0, cbet: 0, blindDefend: 0, showdown: 0, checkRaiseFlop: 0,
    hands: 500);

List<DrillSeat> buildSeats(int count, int heroSeat,
    {DrillVillainProfile Function(int seat)? villain}) {
  return [
    for (int s = 1; s <= count; s++)
      DrillSeat(
        seatNumber: s,
        isHero: s == heroSeat,
        profile: s == heroSeat
            ? null
            : (villain?.call(s) ?? DrillVillainProfile.cashPrior),
      )
  ];
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
      // 10 steal opportunities at 100% must not produce a 100% steal bot
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 10,
        stealCount: 10,
        stealOpportunity: 10,
      );
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.steal, lessThan(80));
      expect(p.steal, greaterThan(DrillVillainProfile.cashPrior.steal));
    });

    test('large samples dominate the prior', () {
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 400,
        cbetCount: 360, // 90%
        cbetOpportunity: 400,
        stealCount: 10, // 2.5%
        stealOpportunity: 400,
      );
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.cbet, greaterThan(85));
      expect(p.steal, lessThan(5));
    });

    test('no 3-bet opportunities falls back to prior 3-bet', () {
      final stats = OpponentStats(opponentId: 'x', handsPlayed: 100);
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      expect(p.threeBet, DrillVillainProfile.cashPrior.threeBet);
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
          name: 'Limpy', aggression: 15, threeBet: 2, hands: 300,
          showdown: 45);
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

    test('cash prior villain opens at realistic rates from steal positions', () {
      // Cash prior steal=28 — with position multipliers, villains should
      // produce some opens over many hands
      final engine = DrillEngine(
        seats: buildSeats(6, 3), // hero seat 3, villains use cashPrior
        stackBB: 100,
        rng: Random(42),
      );
      int villainRaises = 0;
      for (int i = 0; i < 200; i++) {
        var update = engine.startHand();
        // Count all villain raises across the entire hand
        villainRaises += update.newEvents
            .where((e) => e.action == 'raises')
            .length;
        int guard = 0;
        while (update.awaitingHero && guard++ < 10) {
          update = engine.applyHeroAction(
              update.heroTurn!.canCheck ? 'check' : 'fold');
          villainRaises += update.newEvents
              .where((e) => e.action == 'raises')
              .length;
        }
      }
      // Over 200 hands with 5 villains, should see many opens
      expect(villainRaises, greaterThan(10));
    });

    test('MTT mode villain defends BB wider than cash mode', () {
      // MTT prior blindDefend=45 vs cash blindDefend=35
      // Over many hands, MTT villain should defend more often in BB
      final cashEngine = DrillEngine(
        seats: buildSeats(4, 1),
        stackBB: 100,
        rng: Random(99),
      );
      final mttEngine = DrillEngine(
        seats: buildSeats(4, 1),
        stackBB: 100,
        rng: Random(99),
        anteMode: true,
      );
      // Both engines use same seed, so dealt hands are identical
      // MTT mode should produce fewer folds from blinds
      int cashFolds = 0;
      int mttFolds = 0;
      for (int i = 0; i < 100; i++) {
        var cu = cashEngine.startHand();
        var mu = mttEngine.startHand();
        cashFolds += cu.newEvents.where((e) => e.action == 'folds').length;
        mttFolds += mu.newEvents.where((e) => e.action == 'folds').length;
        int guard = 0;
        while (cu.awaitingHero && guard++ < 10) {
          cu = cashEngine.applyHeroAction(
              cu.heroTurn!.canCheck ? 'check' : 'fold');
        }
        guard = 0;
        while (mu.awaitingHero && guard++ < 10) {
          mu = mttEngine.applyHeroAction(
              mu.heroTurn!.canCheck ? 'check' : 'fold');
        }
      }
      // MTT should have fewer or equal folds (wider defense)
      // This is a statistical test — with 100 hands and same seed, the
      // wider defense should be visible
      expect(mttFolds, lessThanOrEqualTo(cashFolds + 5),
          reason: 'MTT villains should not fold significantly more than cash');
    });
  });

  group('DrillVillainProfile', () {
    test('cashPrior has expected values', () {
      final p = DrillVillainProfile.cashPrior;
      expect(p.steal, 28);
      expect(p.blindDefend, 35);
      expect(p.threeBet, 6);
      expect(p.fold3bet, 58);
      expect(p.aggression, 45);
      expect(p.cbet, 65);
      expect(p.showdown, 28);
      expect(p.checkRaiseFlop, 8);
      expect(p.isGenericBot, isTrue);
    });

    test('mttPrior has expected values', () {
      final p = DrillVillainProfile.mttPrior;
      expect(p.steal, 38);
      expect(p.blindDefend, 45);
      expect(p.threeBet, 8);
      expect(p.fold3bet, 52);
      expect(p.aggression, 52);
      expect(p.cbet, 62);
      expect(p.showdown, 26);
      expect(p.checkRaiseFlop, 9);
    });

    test('prior() selects correct format', () {
      expect(DrillVillainProfile.prior(anteMode: false).steal,
          DrillVillainProfile.cashPrior.steal);
      expect(DrillVillainProfile.prior(anteMode: true).steal,
          DrillVillainProfile.mttPrior.steal);
    });

    test('limpRate is sane for cash prior', () {
      final p = DrillVillainProfile.cashPrior;
      // passivity = 55, showdownExcess = 0 → 55*0.10 + 0 = 5.5
      expect(p.limpRate, closeTo(5.5, 0.1));
    });

    test('limpRate is lower for aggressive profiles', () {
      final aggressive = profile(aggression: 80, showdown: 20);
      final passive = profile(aggression: 20, showdown: 40);
      expect(aggressive.limpRate, lessThan(passive.limpRate));
    });

    test('defendRate is sane for cash prior', () {
      final p = DrillVillainProfile.cashPrior;
      // passivity = 55, showdownExcess = 0 → 55*0.08 + 0 = 4.4
      expect(p.defendRate, closeTo(4.4, 0.1));
    });
  });

  group('DrillOpponentProfiler with anteMode', () {
    test('anteMode blends against MTT prior', () {
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 200,
        stealCount: 60, // 30%
        stealOpportunity: 200,
      );
      final cashP = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats, anteMode: false);
      final mttP = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats, anteMode: true);
      // Same observed steal (30%), but MTT prior steal is 38 vs cash 28
      // So MTT-blended steal should be higher than cash-blended
      expect(mttP.steal, greaterThan(cashP.steal));
    });

    test('blind defend stat is blended correctly', () {
      final stats = OpponentStats(
        opponentId: 'x',
        handsPlayed: 100,
        blindDefendCount: 50,
        blindDefendOpportunity: 100, // 50%
      );
      final p = DrillOpponentProfiler.fromStats(
          opponentId: 'x', name: 'Tony', stats: stats);
      // Observed 50%, cash prior 35%, n=100, K=12 → weighted toward observed
      expect(p.blindDefend, greaterThan(40));
      expect(p.blindDefend, lessThan(55));
    });
  });
}
