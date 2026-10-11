import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/services/range_grid_service.dart';

/// HL-2 — mid-hand table change discards the in-progress hand.
/// HL-8 — all-in for less labeled ALL-IN, never limp/call.

void main() {
  group('HL-2 discardCurrentHand', () {
    PokerSessionManager manager() => PokerSessionManager(
        smallBlind: 1, bigBlind: 2, playerCount: 6, ourSeatNumber: 5);

    test('nulls the hand and returns its number for reuse', () {
      final m = manager();
      m.startHand(7, 1);
      m.recordAction(4, PlayerAction.call, BettingRound.preflop, 1,
          playerStack: 200, amount: 2);
      check(m.currentHand != null && m.currentHand!.actions.isNotEmpty,
          'hand in progress');

      final n = m.discardCurrentHand();

      check(n == 7, 'discarded hand number returned, got $n');
      check(m.currentHand == null, 'hand discarded');
      check(m.completedHands.isEmpty, 'nothing saved/completed');
    });

    test('startHand after discard cannot resurrect/auto-save the old hand',
        () {
      final m = manager();
      m.startHand(7, 1);
      m.recordAction(4, PlayerAction.call, BettingRound.preflop, 1,
          playerStack: 200, amount: 2);
      final n = m.discardCurrentHand();

      // The replacement hand reuses the number — no gap, no auto-complete
      // (the hsm:548 trap fires only on a non-null in-progress hand).
      m.startHand(n!, 1);

      check(m.currentHand != null, 'fresh hand open');
      check(m.currentHand!.handNumber == 7, 'hand number reused');
      check(m.currentHand!.actions.isEmpty, 'fresh hand has no actions');
      check(m.completedHands.isEmpty,
          'discarded hand was NOT completed/saved by startHand');
    });

    test('discard with no hand is a safe no-op', () {
      final m = manager();
      check(m.discardCurrentHand() == null, 'null number for no hand');
      check(m.currentHand == null, 'still no hand');
    });
  });

  group('HL-8 all-in-for-less labeling (derivePreflopLine)', () {
    Map<String, dynamic> act(int seat, String action,
            {double? amount, double? stack}) =>
        {
          'player': seat,
          'action': action,
          'street': 'preflop',
          if (amount != null) 'amount': amount,
          if (stack != null) 'playerStack': stack,
        };

    test('call consuming the whole stack labels "All-in call", not "Limped"',
        () {
      // Hero (seat 5) has 80 behind, BB is 100 — calls all-in for less in an
      // unopened pot. Old behavior labeled this "Limped".
      final actions = [act(5, 'call', amount: 80, stack: 80)];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 5);
      check(primary == 'call', 'primaryAction stays call (stats unchanged)');
      check(line == 'All-in call', 'label is All-in call, got "$line"');
      check(scenario == 'rfi', 'unopened pot scenario preserved');
    });

    test('call of a raise for the whole stack labels "All-in call"', () {
      final actions = [
        act(3, 'raise', amount: 60, stack: 500),
        act(5, 'call', amount: 40, stack: 40),
      ];
      final (primary, line, scenario) =
          RangeGridService.derivePreflopLine(actions, 5);
      check(primary == 'call', 'primary stays call');
      check(line == 'All-in call', 'got "$line"');
      check(scenario == 'vs_raise', 'facing a raise');
    });

    test('normal limp and normal call keep their labels', () {
      final limp = RangeGridService.derivePreflopLine(
          [act(5, 'call', amount: 2, stack: 200)], 5);
      check(limp.$2 == 'Limped', 'normal limp unchanged, got "${limp.$2}"');

      final callRaise = RangeGridService.derivePreflopLine([
        act(3, 'raise', amount: 6, stack: 500),
        act(5, 'call', amount: 6, stack: 200),
      ], 5);
      check(callRaise.$2 == 'Called raise',
          'normal call unchanged, got "${callRaise.$2}"');
    });

    test('missing stack info never falsely reports all-in', () {
      final r = RangeGridService.derivePreflopLine(
          [act(5, 'call', amount: 2)], 5);
      check(r.$2 == 'Limped', 'no stack recorded → normal label');
    });
  });
}

void check(bool cond, String msg) {
  if (!cond) throw 'ASSERT: $msg';
}
