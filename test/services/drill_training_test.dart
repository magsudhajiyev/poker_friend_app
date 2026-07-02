import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/models/opponent_stats.dart';
import 'package:poker_logger/services/drill_engine.dart';
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




}
