import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_logger/services/sizing_history_store.dart';

import 'payoff_fixtures.dart';

Future<void> rec(SizingHistoryStore s, SizingKind k, double amt,
    {double bb = 2, double pot = 10, String game = 'cash'}) =>
    s.record(gameType: game, bigBlind: bb, kind: k, amount: amt, pot: pot);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no pre-select below 3 samples; last available from 1', () async {
    final s = SizingHistoryStore();
    await rec(s, SizingKind.open, 5);
    await rec(s, SizingKind.open, 5);
    var sug = await s.suggestionFor(
        gameType: 'cash', bigBlind: 2, kind: SizingKind.open, pot: 3);
    expect(sug.preselect, isNull);
    expect(sug.sameAsLast, 5);
    await rec(s, SizingKind.open, 5);
    sug = await s.suggestionFor(
        gameType: 'cash', bigBlind: 2, kind: SizingKind.open, pot: 3);
    expect(sug.preselect, 5); // 2.5x of BB 2
  });

  test('most used wins and last tracks latest', () async {
    final s = SizingHistoryStore();
    for (final a in [6.0, 6.0, 8.0, 6.0, 8.0]) {
      await rec(s, SizingKind.open, a);
    }
    expect(await s.mostUsed('cash', 2, SizingKind.open), 3.0);
    expect(await s.lastUsed('cash', 2, SizingKind.open), 4.0);
  });

  test('per-kind isolation', () async {
    final s = SizingHistoryStore();
    for (var i = 0; i < 3; i++) {
      await rec(s, SizingKind.open, 5);
    }
    expect(await s.mostUsed('cash', 2, SizingKind.threeBet), isNull);
    expect(await s.lastUsed('cash', 2, SizingKind.cbet), isNull);
  });

  test('bb bucket and game type separate', () async {
    final s = SizingHistoryStore();
    for (var i = 0; i < 3; i++) {
      await rec(s, SizingKind.open, 5);
    }
    expect(await s.mostUsed('cash', 200, SizingKind.open), isNull);
    expect(await s.mostUsed('tournament', 2, SizingKind.open), isNull);
    expect(await s.mostUsed('cash', 2, SizingKind.open), 2.5);
  });

  test('cbet stored as pot fraction and rescaled to the new pot', () async {
    final s = SizingHistoryStore();
    for (var i = 0; i < 3; i++) {
      await rec(s, SizingKind.cbet, 7, pot: 20); // 0.35
    }
    final sug = await s.suggestionFor(
        gameType: 'cash', bigBlind: 2, kind: SizingKind.cbet, pot: 100);
    expect(sug.preselect, closeTo(35, 1e-9));
  });

  test('storage failure falls back to no suggestion', () async {
    final s = SizingHistoryStore(prefs: () async => throw StateError('io'));
    await rec(s, SizingKind.open, 5); // must not throw
    final sug = await s.suggestionFor(
        gameType: 'cash', bigBlind: 2, kind: SizingKind.open, pot: 3);
    expect(sug.isEmpty, isTrue);
  });

  group('SizingContext.classify', () {
    test('preflop open / 3-bet / 4-bet', () {
      expect(SizingContext.classify([], 'preflop', heroSeat: 1), SizingKind.open);
      final one = [act(2, 'raise', 'preflop')];
      expect(SizingContext.classify(one, 'preflop', heroSeat: 1), SizingKind.threeBet);
      final two = [...one, act(3, 'raise', 'preflop')];
      expect(SizingContext.classify(two, 'preflop', heroSeat: 1), isNull);
    });

    test('flop c-bet only as last aggressor and unopened', () {
      final pre = [act(1, 'raise', 'preflop'), act(2, 'call', 'preflop')];
      expect(SizingContext.classify([...pre, act(2, 'check', 'flop')], 'flop', heroSeat: 1),
          SizingKind.cbet);
      expect(SizingContext.classify(pre, 'flop', heroSeat: 2), isNull);
      expect(
          SizingContext.classify([...pre, act(2, 'bet', 'flop')], 'flop', heroSeat: 1),
          isNull);
      expect(SizingContext.classify(pre, 'turn', heroSeat: 1), isNull);
    });
  });
}
