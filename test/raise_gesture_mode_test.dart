import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/overlays/raise_snap_overlay.dart';
import 'package:poker_logger/models/poker_game_state.dart';

/// HL-8b — short-stack raise gesture correctness.
///
/// When the hero's stack can't cover the call, NO raise exists (fold /
/// all-in call only). When it covers the call but not a min-raise, the only
/// legal raise is the all-in shove. The gesture layers must collapse
/// accordingly instead of offering impossible amounts.

void main() {
  group('RaiseSnapOverlay.gestureMode', () {
    test('none when the whole stack cannot exceed the current bet', () {
      expect(
          RaiseSnapOverlay.gestureMode(
              maxBet: 80, currentBet: 100, minRaiseTotal: 200),
          RaiseGestureMode.none);
      // Exactly covering the call is still NOT a raise.
      expect(
          RaiseSnapOverlay.gestureMode(
              maxBet: 100, currentBet: 100, minRaiseTotal: 200),
          RaiseGestureMode.none);
    });

    test('allInOnly when above the call but below a min-raise', () {
      expect(
          RaiseSnapOverlay.gestureMode(
              maxBet: 150, currentBet: 100, minRaiseTotal: 200),
          RaiseGestureMode.allInOnly);
    });

    test('normal from exactly a min-raise upward', () {
      expect(
          RaiseSnapOverlay.gestureMode(
              maxBet: 200, currentBet: 100, minRaiseTotal: 200),
          RaiseGestureMode.normal);
      expect(
          RaiseSnapOverlay.gestureMode(
              maxBet: 5000, currentBet: 100, minRaiseTotal: 200),
          RaiseGestureMode.normal);
    });
  });

  group('snap point generation (short stack)', () {
    test('allInOnlySnapPoints is a single All-In snap', () {
      final points = RaiseSnapOverlay.allInOnlySnapPoints(maxBet: 150);
      expect(points.length, 1);
      expect(points.single.label, 'All-In');
      expect(points.single.amount, 150);
    });

    test('preflop ladder never offers Min above the stack', () {
      // minRaise 200 but stack tops out at 150 → no "Min" snap, no amount
      // above maxBet.
      final points = RaiseSnapOverlay.preflopSnapPoints(
        minRaise: 200,
        bigBlind: 100,
        potAmount: 300,
        maxBet: 150,
        isCashGame: false,
        lastBet: 100,
      );
      expect(points.any((p) => p.label == 'Min'), isFalse);
      for (final p in points) {
        expect(p.amount, lessThanOrEqualTo(150),
            reason: '${p.label} exceeds the stack');
      }
      expect(points.last.label, 'All-In');
      expect(points.last.amount, 150);
    });

    test('postflop ladder never offers Min above the stack', () {
      final points = RaiseSnapOverlay.postflopSnapPoints(
        minBet: 400,
        potAmount: 600,
        maxBet: 250,
        isCashGame: false,
        bigBlind: 100,
        lastBet: 200,
      );
      expect(points.any((p) => p.label == 'Min'), isFalse);
      for (final p in points) {
        expect(p.amount, lessThanOrEqualTo(250));
      }
    });

    test('normal-stack preflop ladder still starts at Min (regression)', () {
      final points = RaiseSnapOverlay.preflopSnapPoints(
        minRaise: 200,
        bigBlind: 100,
        potAmount: 300,
        maxBet: 10000,
        isCashGame: false,
        lastBet: 100,
      );
      expect(points.first.label, 'Min');
      expect(points.first.amount, 200);
      expect(points.last.label, 'All-In');
    });
  });

  group('engine: isValidAction with a short stack', () {
    PokerGameState build(Map<int, double> stacks) {
      final g = PokerGameState(
          numberOfPlayers: 3,
          smallBlind: 1,
          bigBlind: 2,
          isCashGame: true,
          hasBBante: false);
      for (final s in stacks.keys) {
        g.setPlayerActive(s, true);
      }
      stacks.forEach(g.setPlayerStack);
      g.buttonPosition = 1;
      g.finalizeInitialization();
      g.initializePot();
      return g;
    }

    test('raise INVALID when stack cannot exceed the current bet (HL-8b)',
        () {
      // 3-handed, BTN=1 acts first. BTN raises to 10; SB folds; BB has 2
      // posted + 3 behind = 5 total < 10 → call all-in only, no raise.
      final g = build({1: 200.0, 2: 200.0, 3: 5.0});
      g.performActionWithAmount(PlayerAction.raise, 10); // BTN
      g.performAction(PlayerAction.fold); // SB
      expect(g.currentPlayer, 3, reason: 'BB to act');
      expect(g.isValidAction(PlayerAction.raise), isFalse,
          reason: 'stack ≤ call amount → no raise exists');
      expect(g.isValidAction(PlayerAction.call), isTrue,
          reason: 'all-in call must stay available');
      expect(g.isValidAction(PlayerAction.fold), isTrue);
    });

    test('raise VALID when the stack can exceed the current bet', () {
      final g = build({1: 200.0, 2: 200.0, 3: 50.0});
      g.performActionWithAmount(PlayerAction.raise, 10); // BTN
      g.performAction(PlayerAction.fold); // SB
      expect(g.currentPlayer, 3);
      expect(g.isValidAction(PlayerAction.raise), isTrue,
          reason: 'shove above the bet is a legal (all-in) raise');
    });

    test('all-in call for less still resolves the hand state correctly', () {
      final g = build({1: 200.0, 2: 200.0, 3: 5.0});
      g.performActionWithAmount(PlayerAction.raise, 10); // BTN
      g.performAction(PlayerAction.fold); // SB
      g.performAction(PlayerAction.call); // BB all-in for 5 total
      final bb = g.players[2];
      expect(bb.isAllIn, isTrue);
      expect(bb.currentStack, 0);
      expect(bb.betThisRound, 5, reason: '2 posted + 3 behind');
      // Chip conservation: 10 (BTN) + 1 (folded SB) + 5 (BB) = 16.
      expect(g.currentPot, 16);
    });
  });
}
