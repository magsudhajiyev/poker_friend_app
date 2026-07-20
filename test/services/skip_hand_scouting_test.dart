import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/skip_hand_scouting_service.dart';
import 'package:poker_logger/services/stats_calculator.dart';

/// Tests for the preflop scouting synthesizer. `buildPreflopActions` turns a
/// per-seat capture into an ordered preflop action list; we assert that list
/// feeds the (real) StatsCalculator detectors to the correct results — the same
/// detectors used for fully-logged hands.
///
/// Table for all tests: 6-max, seats 1..6, button = seat 6.
///   Positions: SB=1, BB=2, UTG=3, HJ=4, CO=5, BTN=6
///   Action order (UTG→BB): 3, 4, 5, 6, 1, 2
///   Steal positions: CO(5), BTN(6), SB(1)
void main() {
  const activeSeats = {1, 2, 3, 4, 5, 6};
  const button = 6;
  const hero = 4; // HJ — hero folds and scouts.

  List<Map<String, dynamic>> build(SkipScoutResult result) {
    return SkipHandScoutingService.buildPreflopActions(
      result: result,
      playerNames: const {
        1: 'Alice', 2: 'Bob', 3: 'Cara', 4: 'Hero', 5: 'Dan', 6: 'Eve',
      },
      activeSeats: activeSeats,
      heroSeat: hero,
      buttonPosition: button,
    );
  }

  group('buildPreflopActions — structure', () {
    test('emits SB/BB blind posts and a hero fold', () {
      final actions = build(const SkipScoutResult.noRaise());
      // blinds present
      expect(
        actions.any((a) => a['player'] == 1 && a['action'] == 'small blind'),
        isTrue,
      );
      expect(
        actions.any((a) => a['player'] == 2 && a['action'] == 'big blind'),
        isTrue,
      );
      // hero folded
      expect(
        actions.any((a) => a['player'] == hero && a['action'] == 'fold'),
        isTrue,
      );
      // every entry is preflop and carries a position
      for (final a in actions) {
        expect(a['street'], 'preflop');
        expect(a.containsKey('playerPosition'), isTrue);
      }
    });
  });

  group('folded around (no raise)', () {
    late List<Map<String, dynamic>> actions;
    setUp(() => actions = build(const SkipScoutResult.noRaise()));

    test('is a walk for the BB', () {
      expect(StatsCalculator.isWalkHand(actions), isTrue);
      expect(StatsCalculator.findBigBlindSeat(actions), 2);
    });

    test('late-position seats had a steal opportunity but did not steal', () {
      // CO(5) and BTN(6) fold in an unopened pot → steal opp, no steal.
      expect(StatsCalculator.hadStealOpportunity(actions, 5), isTrue);
      expect(StatsCalculator.didSteal(actions, 5), isFalse);
      expect(StatsCalculator.hadStealOpportunity(actions, 6), isTrue);
      expect(StatsCalculator.didSteal(actions, 6), isFalse);
    });

    test('nobody 3-bet or had a 3-bet opportunity', () {
      for (final seat in [1, 2, 3, 5, 6]) {
        expect(StatsCalculator.didPlayerThreeBet(actions, seat), isFalse);
        expect(StatsCalculator.hadThreeBetOpportunity(actions, seat), isFalse);
      }
    });
  });

  group('single open (steal attempt from BTN)', () {
    late List<Map<String, dynamic>> actions;
    setUp(() {
      // BTN(6) opens; everyone else folds.
      actions = build(const SkipScoutResult.detailed(
        seatActions: {6: SkipSeatAction.raise},
        raiseOrder: [6],
      ));
    });

    test('BTN opener stole; no 3-bet in the hand', () {
      expect(StatsCalculator.hadStealOpportunity(actions, 6), isTrue);
      expect(StatsCalculator.didSteal(actions, 6), isTrue);
      expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse); // open, not 3-bet
    });

    test('a blind facing the open (no defend) had a blind-defend opportunity', () {
      // BB(2) folds to the open → blind-defend opportunity, not defended.
      expect(StatsCalculator.hadBlindDefendOpportunity(actions, 2), isTrue);
      expect(StatsCalculator.didBlindDefend(actions, 2), isFalse);
    });
  });

  group('open + 3-bet + opener folds', () {
    late List<Map<String, dynamic>> actions;
    setUp(() {
      // UTG(3) opens (1st raise), CO(5) 3-bets (2nd raise), UTG folds to it.
      actions = build(const SkipScoutResult.detailed(
        seatActions: {3: SkipSeatAction.raise, 5: SkipSeatAction.raise},
        raiseOrder: [3, 5],
        openerResponse: OpenerResponse.fold,
      ));
    });

    test('the 2nd raiser (CO) 3-bet', () {
      expect(StatsCalculator.didPlayerThreeBet(actions, 5), isTrue);
      expect(StatsCalculator.didPlayerThreeBet(actions, 3), isFalse); // opener
    });

    test('the opener faced a 3-bet and folded to it', () {
      expect(StatsCalculator.facedThreeBet(actions, 3), isTrue);
      expect(StatsCalculator.didFoldTo3Bet(actions, 3), isTrue);
    });

    test('the opener had a steal-that-became-3bet? no — UTG is not a steal seat', () {
      expect(StatsCalculator.hadStealOpportunity(actions, 3), isFalse);
    });
  });

  group('open + call (flat, no 3-bet)', () {
    late List<Map<String, dynamic>> actions;
    setUp(() {
      // CO(5) opens, BTN(6) flats.
      actions = build(const SkipScoutResult.detailed(
        seatActions: {5: SkipSeatAction.raise, 6: SkipSeatAction.call},
        raiseOrder: [5],
      ));
    });

    test('caller had a 3-bet opportunity but declined; is not a 3-bettor', () {
      expect(StatsCalculator.hadThreeBetOpportunity(actions, 6), isTrue);
      expect(StatsCalculator.didPlayerThreeBet(actions, 6), isFalse);
    });

    test('opener did not face a 3-bet', () {
      expect(StatsCalculator.facedThreeBet(actions, 5), isFalse);
    });
  });

  group('squeeze: LP open, blind 3-bets (order preserved despite seat order)', () {
    late List<Map<String, dynamic>> actions;
    setUp(() {
      // CO(5) opens (1st raise), SB(1) squeezes (2nd raise = 3-bet).
      // SB sits EARLIER in seat number but LATER in action order — raiseOrder
      // is the source of truth, so CO must be the open and SB the 3-bet.
      actions = build(const SkipScoutResult.detailed(
        seatActions: {5: SkipSeatAction.raise, 1: SkipSeatAction.raise},
        raiseOrder: [5, 1],
        openerResponse: OpenerResponse.call,
      ));
    });

    test('CO opened, SB 3-bet (squeeze)', () {
      expect(StatsCalculator.didPlayerThreeBet(actions, 1), isTrue);  // SB squeeze
      expect(StatsCalculator.didPlayerThreeBet(actions, 5), isFalse); // CO opener
      expect(StatsCalculator.facedThreeBet(actions, 5), isTrue);
      expect(StatsCalculator.didFoldTo3Bet(actions, 5), isFalse);     // opener called
    });
  });
}
