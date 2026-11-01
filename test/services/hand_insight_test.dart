import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/hand_insight.dart';

import 'payoff_fixtures.dart';

Map<String, dynamic> openHand({double pot = 20, String pos = 'CO'}) => handMap([
      act(1, 'raise', 'preflop'),
      act(2, 'fold', 'preflop'),
    ], pos: pos, pot: pot);

Map<String, dynamic> noFlopHand() => handMap([
      act(2, 'raise', 'preflop'),
      act(1, 'fold', 'preflop'),
    ], pot: 5);

void main() {
  test('null on empty tallies for a plain hand', () {
    expect(insightFor(record(noFlopHand()), SessionTallies()), isNull);
  });

  test('nth open from position needs n>=3', () {
    final t = SessionTallies();
    t.record(openHand());
    expect(insightFor(record(openHand()), t), isNull); // would be 2nd
    t.record(openHand());
    final i = insightFor(record(openHand()), t)!;
    expect(i.kind, HandInsightKind.opens);
    expect([i.n, i.position], [3, 'CO']);
  });

  test('open counts are per position', () {
    final t = SessionTallies();
    t.record(openHand(pos: 'CO'));
    t.record(openHand(pos: 'CO'));
    expect(insightFor(record(openHand(pos: 'BTN')), t), isNull);
  });

  test('biggest pot needs 5 prior hands and a larger pot', () {
    final t = SessionTallies();
    for (var i = 0; i < 4; i++) {
      t.record(noFlopHand());
    }
    expect(insightFor(record(openHand(pot: 500)), t)?.kind,
        isNot(HandInsightKind.biggestPot));
    t.record(noFlopHand());
    expect(insightFor(record(openHand(pot: 500)), t)?.kind,
        HandInsightKind.biggestPot);
    expect(insightFor(record(openHand(pot: 2)), t)?.kind,
        isNot(HandInsightKind.biggestPot));
  });

  test('fold-to-cbet percentage with n spots, hidden below 3', () {
    final t = SessionTallies();
    Map<String, dynamic> facing(bool fold) => handMap([
          act(3, 'raise', 'preflop'),
          act(1, 'call', 'preflop'),
          act(3, 'bet', 'flop'),
          act(1, fold ? 'fold' : 'call', 'flop'),
        ], pot: 1);
    t.record(facing(true));
    expect(insightFor(record(facing(true)), t), isNull); // 2nd spot
    t.record(facing(false));
    final i = insightFor(record(facing(true)), t)!;
    expect(i.kind, HandInsightKind.foldCbet);
    expect([i.n, i.pct], [3, 67]);
  });

  test('no-flop streak needs 5 in a row', () {
    final t = SessionTallies();
    for (var i = 0; i < 3; i++) {
      t.record(noFlopHand());
    }
    expect(insightFor(record(noFlopHand()), t), isNull); // 4th
    t.record(noFlopHand());
    final i = insightFor(record(noFlopHand()), t)!;
    expect([i.kind, i.n], [HandInsightKind.noFlop, 5]);
  });

  test('stubs and scouted hands are not analyzable', () {
    final t = SessionTallies();
    t.record({...openHand(), 'completeness': 'flagged'});
    t.record({...openHand(), 'isScouted': true});
    expect(t.hands, 0);
    expect(
        insightFor(record({...openHand(), 'completeness': 'flagged'}), t), isNull);
  });
}
