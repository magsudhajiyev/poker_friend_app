import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/villain_tracker.dart';

import 'payoff_fixtures.dart';

void main() {
  test('hidden below n=3, exactly 3/3 at n=3', () {
    final t = VillainTracker();
    for (var i = 0; i < 2; i++) {
      t.onHandCompleted(cbetHand());
    }
    expect(t.lineFor(3, VillainLineKind.foldedToCbet), isNull);
    t.onHandCompleted(cbetHand());
    final line = t.lineFor(3, VillainLineKind.foldedToCbet)!;
    expect([line.count, line.total], [3, 3]);
  });

  test('counts folds and calls separately', () {
    final t = VillainTracker();
    t.onHandCompleted(cbetHand());
    t.onHandCompleted(cbetHand(fold: false));
    t.onHandCompleted(cbetHand());
    final l = t.lineFor(3, VillainLineKind.foldedToCbet)!;
    expect([l.count, l.total], [2, 3]);
  });

  test('per-seat isolation', () {
    final t = VillainTracker();
    for (var i = 0; i < 3; i++) {
      t.onHandCompleted(cbetHand());
    }
    expect(t.lineFor(5, VillainLineKind.foldedToCbet), isNull);
    expect(t.lineFor(1, VillainLineKind.foldedToCbet), isNull); // aggressor
  });

  test('reset clears session', () {
    final t = VillainTracker();
    for (var i = 0; i < 3; i++) {
      t.onHandCompleted(cbetHand());
    }
    t.reset();
    expect(t.lineFor(3, VillainLineKind.foldedToCbet), isNull);
  });

  test('fold ticks and flagged stubs are ignored', () {
    final t = VillainTracker();
    for (var i = 0; i < 3; i++) {
      t.onHandCompleted({...cbetHand(), 'completeness': 'fold_tick'});
      t.onHandCompleted({...cbetHand(), 'completeness': 'flagged'});
    }
    expect(t.lineFor(3, VillainLineKind.foldedToCbet), isNull);
  });

  test('vpip and 3-bet tallies', () {
    final t = VillainTracker();
    for (var i = 0; i < 3; i++) {
      t.onHandCompleted(handMap([
        act(4, 'raise', 'preflop'),
        act(3, 'raise', 'preflop'),
        act(4, 'fold', 'preflop'),
      ]));
    }
    final v = t.lineFor(3, VillainLineKind.vpip)!;
    expect([v.count, v.total], [3, 3]);
    final b = t.lineFor(3, VillainLineKind.threeBets)!;
    expect([b.count, b.total], [3, 3]);
    final f = t.lineFor(4, VillainLineKind.foldedTo3Bet)!;
    expect([f.count, f.total], [3, 3]);
  });

  test('lineAfterAction picks the trigger from the live hand', () {
    final t = VillainTracker();
    for (var i = 0; i < 3; i++) {
      t.onHandCompleted(cbetHand());
    }
    final live = [
      act(1, 'raise', 'preflop'),
      act(3, 'call', 'preflop'),
      act(1, 'bet', 'flop'),
      act(3, 'fold', 'flop'),
    ];
    final l = t.lineAfterAction(live, 3)!;
    expect(l.kind, VillainLineKind.foldedToCbet);
    expect(t.lineAfterAction(live.take(2).toList(), 3)!.kind, VillainLineKind.vpip);
  });
}
