import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/services/hand_stats_plan.dart';
import 'package:poker_logger/services/stats_calculator.dart';

import '../fixtures/mock_hand_actions.dart';

typedef A = MockHandActions;

/// Hero = seat 4 on the BTN opens, seat 6 (BB) calls, hero c-bets, wins.
List<Map<String, dynamic>> _openAndCbet() => [
      A.smallBlind(5, 1),
      A.bigBlind(6, 2),
      A.raise(4, 5, position: 'BTN'),
      A.fold(5),
      A.call(6, 3),
      A.bet(4, 4, street: 'flop', position: 'BTN'),
      A.fold(6, street: 'flop'),
    ];

List<Map<String, dynamic>> _heroBbWalk() => [
      A.smallBlind(5, 1),
      A.bigBlind(4, 2),
      A.fold(6),
      A.fold(1),
      A.fold(2),
      A.fold(3),
      A.fold(5),
    ];

/// Verbatim copy of the pre-refactor `_updateUserStatsFromHand` arithmetic.
Map<String, int> _legacy(List<Map<String, dynamic>> actions, int seat,
    int? winnerId, List<int>? chopped) {
  bool didPlay = false, didVpip = false, didPfr = false, didWin = false;
  if ((winnerId != null && winnerId == seat) ||
      (chopped?.contains(seat) ?? false)) {
    didWin = true;
  }
  for (final a in actions) {
    if (a['player'] != seat) continue;
    final t = a['action']?.toString().toLowerCase() ?? '';
    final st = a['street']?.toString().toLowerCase() ?? '';
    if (t == 'call' || t == 'bet' || t == 'raise' || t == 'all-in' || t == 'check') {
      didPlay = true;
    }
    if (st == 'preflop') {
      if (t == 'bet' || t == 'call' || t == 'raise' || t == 'all-in') {
        if (!StatsCalculator.isBlindAction(a)) didVpip = true;
        if (t == 'bet' || t == 'raise' || t == 'all-in') didPfr = true;
      }
    }
  }
  final three = didPlay && StatsCalculator.didPlayerThreeBet(actions, seat);
  final walk = StatsCalculator.isWalkHand(actions);
  final bbWalk = walk && StatsCalculator.isBigBlind(actions, seat);
  final cOpp = StatsCalculator.hadCbetOpportunity(actions, seat);
  final sOpp = StatsCalculator.hadStealOpportunity(actions, seat);
  final crOpp = StatsCalculator.hadCheckRaiseFlopOpportunity(actions, seat);
  final bdOpp = StatsCalculator.hadBlindDefendOpportunity(actions, seat);
  return {
    'total': 1,
    'walks': bbWalk ? 1 : 0,
    'hands': didPlay ? 1 : 0,
    'vpip': didVpip ? 1 : 0,
    'pfr': didPfr ? 1 : 0,
    'three': three ? 1 : 0,
    'threeOpp': StatsCalculator.hadThreeBetOpportunity(actions, seat) ? 1 : 0,
    'fold3': StatsCalculator.didFoldTo3Bet(actions, seat) ? 1 : 0,
    'facing3': StatsCalculator.facedThreeBet(actions, seat) ? 1 : 0,
    'cbet': cOpp && StatsCalculator.didCbet(actions, seat) ? 1 : 0,
    'cbetOpp': cOpp ? 1 : 0,
    'steal': sOpp && StatsCalculator.didSteal(actions, seat) ? 1 : 0,
    'stealOpp': sOpp ? 1 : 0,
    'cr': crOpp && StatsCalculator.didCheckRaiseFlop(actions, seat) ? 1 : 0,
    'crOpp': crOpp ? 1 : 0,
    'bd': bdOpp && StatsCalculator.didBlindDefend(actions, seat) ? 1 : 0,
    'bdOpp': bdOpp ? 1 : 0,
    'won': (didWin && didPlay) ? 1 : 0,
  };
}

Map<String, int> _asMap(HeroHandDelta d) => {
      'total': d.totalHands,
      'walks': d.walks,
      'hands': d.hands,
      'vpip': d.vpip,
      'pfr': d.pfr,
      'three': d.threeBet,
      'threeOpp': d.threeBetOpp,
      'fold3': d.fold3bet,
      'facing3': d.facing3Bet,
      'cbet': d.cbet,
      'cbetOpp': d.cbetOpp,
      'steal': d.steal,
      'stealOpp': d.stealOpp,
      'cr': d.checkRaiseFlop,
      'crOpp': d.checkRaiseFlopOpp,
      'bd': d.blindDefend,
      'bdOpp': d.blindDefendOpp,
      'won': d.wonHands,
    };

void main() {
  group('golden: full mode equals the legacy arithmetic', () {
    final scenarios = <String, (List<Map<String, dynamic>>, int, int?)>{
      'open + cbet win': (_openAndCbet(), 4, 4),
      'bb walk': (_heroBbWalk(), 4, 4),
      'hero folds to raise': (
        [
          A.smallBlind(5, 1),
          A.bigBlind(6, 2),
          A.raise(1, 6, position: 'UTG'),
          A.fold(4, position: 'BTN'),
          A.fold(5),
          A.fold(6),
        ],
        4,
        1
      ),
      '3-bet then fold to 4-bet': (
        [
          A.smallBlind(5, 1),
          A.bigBlind(6, 2),
          A.raise(1, 6, position: 'UTG'),
          A.raise(4, 18, position: 'BTN'),
          A.fold(5),
          A.fold(6),
          A.raise(1, 40, position: 'UTG'),
          A.fold(4, position: 'BTN'),
        ],
        4,
        1
      ),
    };
    for (final e in scenarios.entries) {
      test(e.key, () {
        final (actions, seat, winner) = e.value;
        final d = computeHeroDelta(
            actions: actions,
            heroPositionName: 'BTN',
            heroSeatNumber: seat,
            winnerId: winner);
        expect(_asMap(d), _legacy(actions, seat, winner, null));
      });
    }
  });

  group('heroModeFor / opponentsFeedFor', () {
    test('all five levels', () {
      expect(heroModeFor(HandCompleteness.foldTick), HeroStatsMode.totalsOnly);
      expect(heroModeFor(HandCompleteness.preflop), HeroStatsMode.preflopOnly);
      expect(heroModeFor(HandCompleteness.flagged), HeroStatsMode.none);
      expect(heroModeFor(HandCompleteness.reconstructed), HeroStatsMode.full);
      expect(heroModeFor(HandCompleteness.full), HeroStatsMode.full);
      expect(opponentsFeedFor(HandCompleteness.foldTick), isFalse);
      expect(opponentsFeedFor(HandCompleteness.preflop), isTrue);
      expect(opponentsFeedFor(HandCompleteness.flagged), isFalse);
      expect(opponentsFeedFor(HandCompleteness.reconstructed),
          kReconstructedFeedsOpponents);
      expect(opponentsFeedFor(HandCompleteness.full), isTrue);
    });
  });

  group('computeHeroDelta', () {
    test('none -> empty; foldTick -> totalHands 1 only, position null', () {
      final none = computeHeroDelta(
          actions: _openAndCbet(),
          heroPositionName: 'BTN',
          heroSeatNumber: 4,
          winnerId: 4,
          mode: HeroStatsMode.none);
      expect(none.isEmpty, isTrue);
      final tick = computeHeroDelta(
          actions: const [],
          heroPositionName: 'BTN',
          heroSeatNumber: 4,
          winnerId: null,
          mode: HeroStatsMode.totalsOnly);
      expect(tick.totalHands, 1);
      expect(tick.position, isNull);
      expect(
          HeroHandDelta.foldTick.isEmpty, isFalse); // sanity: has totalHands
      final onlyTotal = HeroHandDelta(totalHands: tick.totalHands);
      expect(tick.isEmpty, onlyTotal.isEmpty);
    });

    test('full: open + c-bet win counts everything', () {
      final d = computeHeroDelta(
          actions: _openAndCbet(),
          heroPositionName: 'BTN',
          heroSeatNumber: 4,
          winnerId: 4);
      expect(d.totalHands, 1);
      expect(d.hands, 1);
      expect(d.vpip, 1);
      expect(d.pfr, 1);
      expect(d.wonHands, 1);
      expect(d.position, 'BTN');
    });

    test('preflopOnly zeroes hands/won/cbet/check-raise but keeps preflop', () {
      final full = computeHeroDelta(
          actions: _openAndCbet(),
          heroPositionName: 'BTN',
          heroSeatNumber: 4,
          winnerId: 4);
      final pre = computeHeroDelta(
          actions: _openAndCbet(),
          heroPositionName: 'BTN',
          heroSeatNumber: 4,
          winnerId: 4,
          mode: HeroStatsMode.preflopOnly);
      expect(pre.totalHands, 1);
      expect(pre.vpip, full.vpip);
      expect(pre.pfr, full.pfr);
      expect(pre.stealOpp, full.stealOpp);
      expect(pre.hands, 0);
      expect(pre.wonHands, 0);
      expect(pre.cbet, 0);
      expect(pre.cbetOpp, 0);
      expect(pre.checkRaiseFlop, 0);
      expect(pre.checkRaiseFlopOpp, 0);
    });

    test('BB walk adds walks (once, through the full path)', () {
      final d = computeHeroDelta(
          actions: _heroBbWalk(),
          heroPositionName: 'BB',
          heroSeatNumber: 4,
          winnerId: 4);
      expect(d.walks, 1);
      expect(d.totalHands, 1);
    });

    test('missing seat or position -> empty delta (never throws)', () {
      expect(
          computeHeroDelta(
                  actions: _openAndCbet(),
                  heroPositionName: null,
                  heroSeatNumber: 4,
                  winnerId: 4)
              .isEmpty,
          isTrue);
    });
  });
}
