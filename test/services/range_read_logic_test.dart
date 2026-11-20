import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/daily_challenge_store.dart';
import 'package:poker_logger/services/daily_scoring.dart';
import 'package:poker_logger/services/range_read_logic.dart';

TreeNode _node({
  required Map<String, double> call,
  Map<String, double>? raise,
  List<String> board = const [],
  String id = 'n1',
  TreeStreet street = TreeStreet.preflop,
  double toCall = 2,
}) =>
    TreeNode(
      id: id,
      street: street,
      board: board,
      actor: TreeActor.hero,
      potBB: 6,
      toCallBB: toCall,
      prompt: '',
      actions: const [AuthoredAction.call, AuthoredAction.raise],
      sizingBB: const {},
      freq: {
        AuthoredAction.call: call,
        if (raise != null) AuthoredAction.raise: raise,
      },
      children: const {},
    );

AuthoredTree _tree(TreeNode n, {List<String> hero = const ['9♠', '9♥']}) =>
    AuthoredTree(
      id: 't1',
      title: 't',
      formatLabel: '',
      stackBB: 100,
      anteMode: false,
      heroPosition: 'LJ',
      villainPosition: 'BTN',
      heroCards: hero,
      heroHandClass: '99',
      nodes: {n.id: n},
      rootId: n.id,
    );

// 3 strong callers, 4 clear non-callers, one mixed hand.
final _call = <String, double>{
  '99': 1.0,
  'KQs': 0.92,
  'JTs': 0.8,
  'AQo': 0.7,
  '76s': 0.0,
  'A5o': 0.05,
  '32o': 0.0,
  'T9o': 0.1,
  'ATs': 0.4,
};

DrillDecisionRecord _rec(String g) => DrillDecisionRecord(
      handNumber: 1,
      handClass: '99',
      position: 'LJ',
      scenario: DrillScenario.vsRaise,
      result: DrillGradeResult(
        grade: g == 'c'
            ? DrillGrade.correct
            : (g == 'o' ? DrillGrade.ok : DrillGrade.mistake),
        heroAction: 'call',
        recommendedAction: 'call',
        explanation: '',
      ),
    );

void main() {

  group('card combos', () {
    final dead = RangeReadLogic.deadKeys(['9♠', '9♥', 'K♠', 'Q♠', '2♦']);

    test('comboFor is live, deterministic, matches the class', () {
      for (final hc in ['KQs', '99', '76o', 'AQo', 'JTs']) {
        final c = RangeReadLogic.comboFor(hc, dead, 'x|$hc');
        expect(c.length, 2);
        expect(RangeReadLogic.deadKeys(c).intersection(dead), isEmpty);
        expect(c, RangeReadLogic.comboFor(hc, dead, 'x|$hc'));
        final r = [c[0].substring(0, 1), c[1].substring(0, 1)];
        final su = [c[0].substring(1), c[1].substring(1)];
        expect(r, [hc[0], hc[1]]);
        if (hc.endsWith('s')) expect(su[0], su[1]);
        if (hc.endsWith('o')) expect(su[0] == su[1], isFalse);
        if (hc[0] == hc[1]) expect(r[0], r[1]);
      }
    });

    test('comboFor empty when all combos are blocked', () {
      final all = RangeReadLogic.deadKeys(['A♠', 'A♥', 'A♦']);
      expect(RangeReadLogic.comboFor('AA', all, 's'), isEmpty);
    });

    test('options carry distinct live cards', () {
      final n = _node(call: _call, board: ['K♠', 'Q♠', '2♦']);
      final t = _tree(n);
      for (var i = 0; i < 20; i++) {
        final q = RangeReadLogic.build(
            tree: t, node: n, picked: AuthoredAction.call, seed: 's$i')!;
        final all = [for (final o in q.options) ...o.cards];
        expect(all.length, 6);
        expect(all.toSet().length, 6);
        final d = RangeReadLogic.deadKeys(['9♠', '9♥', 'K♠', 'Q♠', '2♦']);
        expect(RangeReadLogic.deadKeys(all).intersection(d), isEmpty);
      }
    });

    test('JSON round-trip with and without cards', () {
      const withC = RangeReadOption('KQs', 0.9, cards: ['K♥', 'Q♥']);
      final back = RangeReadOption.fromJson(withC.toJson());
      expect(back.cards, ['K♥', 'Q♥']);
      const none = RangeReadOption('KQs', 0.9);
      expect(none.toJson().containsKey('c'), isFalse);
      expect(RangeReadOption.fromJson({'h': 'KQs', 'f': 0.9}).cards, isEmpty);
    });
  });
  group('combos / blockers', () {
    test('base combo counts', () {
      expect(RangeReadLogic.liveCombos('99', {}), 6);
      expect(RangeReadLogic.liveCombos('KQs', {}), 4);
      expect(RangeReadLogic.liveCombos('KQo', {}), 12);
    });

    test('dead cards remove combos; glyph 10 maps to T', () {
      final dead = RangeReadLogic.deadKeys(['10♠', '9♣', 'K♥']);
      expect(dead, {'Ts', '9c', 'Kh'});
      expect(RangeReadLogic.liveCombos('T9s', dead), 2); // s: Ts dead; c: 9c dead
      expect(RangeReadLogic.liveCombos('99', {'9s', '9h', '9d'}), 0);
      expect(RangeReadLogic.liveCombos('99', {'9s', '9h'}), 1);
      expect(RangeReadLogic.liveCombos('KQs', {'Ks', 'Kh', 'Kd', 'Kc'}), 0);
      expect(RangeReadLogic.liveCombos('KQo', {'Ks'}), 9);
    });
  });

  group('build', () {
    test('options: 1 correct + 2 wrong by threshold, hero class excluded', () {
      final n = _node(call: _call);
      final t = _tree(n);
      for (var i = 0; i < 40; i++) {
        final q = RangeReadLogic.build(
            tree: t, node: n, picked: AuthoredAction.call, seed: 's$i')!;
        expect(q.options.length, 3);
        expect(q.options.map((o) => o.hand), isNot(contains('99')));
        expect(q.options.map((o) => o.hand), isNot(contains('ATs'))); // mixed
        final strong =
            q.options.where((o) => o.freq >= RangeReadLogic.strong).toList();
        final weak =
            q.options.where((o) => o.freq <= RangeReadLogic.weak).toList();
        if (q.type == RangeReadType.also) {
          expect(strong.length, 1);
          expect(weak.length, 2);
          expect(q.options[q.correctIndex].freq, greaterThanOrEqualTo(0.65));
        } else {
          expect(weak.length, 1);
          expect(strong.length, 2);
          expect(q.options[q.correctIndex].freq, lessThanOrEqualTo(0.10));
        }
      }
    });

    test('both question types occur across seeds', () {
      final n = _node(call: _call);
      final t = _tree(n);
      final types = {
        for (var i = 0; i < 40; i++)
          RangeReadLogic.build(
                  tree: t, node: n, picked: AuthoredAction.call, seed: 'x$i')!
              .type
      };
      expect(types, {RangeReadType.also, RangeReadType.not});
    });

    test('deterministic: same seed, same question', () {
      final n = _node(call: _call);
      final t = _tree(n);
      final a = RangeReadLogic.build(
          tree: t, node: n, picked: AuthoredAction.call, seed: 'k')!;
      final b = RangeReadLogic.build(
          tree: t, node: n, picked: AuthoredAction.call, seed: 'k')!;
      expect(a.toJson(), b.toJson());
    });

    test('falls back to the other type when one is unbuildable', () {
      // Only ONE clearly-out hand: ALSO needs 2 wrong → impossible; NOT needs
      // 1 correct (the one weak) + 2 strong → buildable.
      final n = _node(call: {'99': 1, 'KQs': 0.9, 'JTs': 0.8, 'AQo': 0.7, '76s': 0});
      final t = _tree(n);
      for (var i = 0; i < 20; i++) {
        final q = RangeReadLogic.build(
            tree: t, node: n, picked: AuthoredAction.call, seed: 'f$i')!;
        expect(q.type, RangeReadType.not);
        expect(q.options[q.correctIndex].hand, '76s');
      }
    });

    test('not eligible: no clear hands / action never taken', () {
      final mixed = _node(call: {'99': 1, 'KQs': 0.4, 'JTs': 0.5, 'AQo': 0.3});
      expect(
          RangeReadLogic.build(
              tree: _tree(mixed),
              node: mixed,
              picked: AuthoredAction.call,
              seed: 's'),
          isNull);
      // Picked action has no frequencies at all (synthetic bet).
      final n = _node(call: _call);
      expect(
          RangeReadLogic.build(
              tree: _tree(n), node: n, picked: AuthoredAction.raise, seed: 's'),
          isNull);
    });

    test('hands with zero live combos never appear', () {
      // Board + hero kill every 76s / T9o / A5o / 32o combo.
      final n = _node(
        call: _call,
        board: const ['7♠', '7♥', '7♦', '7♣', '6♠'],
        street: TreeStreet.river,
      );
      final t = _tree(n, hero: const ['6♥', '6♦']);
      // 76s: 7s,7h,7d,7c dead => 0 live. KQs/JTs/AQo/A5o/32o/T9o alive.
      for (var i = 0; i < 40; i++) {
        final q = RangeReadLogic.build(
            tree: t, node: n, picked: AuthoredAction.call, seed: 'd$i');
        expect(q?.options.map((o) => o.hand) ?? const <String>[],
            isNot(contains('76s')));
      }
    });

    test('action word: bet postflop with nothing to call, else raise', () {
      final n = _node(
          call: _call, street: TreeStreet.flop, toCall: 0, board: const ['2♣']);
      expect(RangeReadLogic.wordFor(AuthoredAction.raise, n), 'bet');
      expect(RangeReadLogic.wordFor(AuthoredAction.allin, n), 'jam');
      expect(
          RangeReadLogic.wordFor(AuthoredAction.raise, _node(call: _call)),
          'raise');
    });
  });

  group('plan (which decision gets it)', () {
    final n = _node(call: _call);
    final t = _tree(n);
    RangeReadPlan plan(
            {int seen = 0,
            bool asked = false,
            bool over = false,
            int letters = 1,
            String day = '2026-11-20'}) =>
        RangeReadLogic.plan(
            dayKey: day,
            tree: t,
            node: n,
            picked: AuthoredAction.call,
            eligibleSeen: seen,
            alreadyAsked: asked,
            handOver: over,
            letterCount: letters);

    test('target decision is the 1st or 2nd eligible, per day+tree', () {
      final days = [for (var d = 1; d <= 20; d++) '2026-11-${d.toString().padLeft(2, '0')}'];
      final firsts = days.where((d) => plan(day: d).ask).length;
      expect(firsts, inInclusiveRange(1, 19)); // both targets occur
      for (final d in days) {
        // At the 2nd eligible decision it ALWAYS asks.
        expect(plan(day: d, seen: 1).ask, isTrue);
        // Same inputs, same answer.
        expect(plan(day: d).ask, plan(day: d).ask);
      }
    });

    test('hand over before the target is reached → ask at the last one', () {
      final d = [
        for (var i = 1; i <= 20; i++) '2026-11-${i.toString().padLeft(2, '0')}'
      ].firstWhere((d) => !plan(day: d).ask);
      expect(plan(day: d, over: true).ask, isTrue);
    });

    test('max one per hand; never in a hand with >= 10 letters', () {
      expect(plan(asked: true, seen: 5, over: true).question, isNull);
      expect(plan(letters: 10, seen: 5, over: true).question, isNull);
      expect(plan(letters: 9, seen: 5, over: true).ask, isTrue);
    });

    test('gate: needs both the screen param and the flag', () {
      expect(RangeReadLogic.enabled(screenAllows: true, flagOn: true), isTrue);
      expect(RangeReadLogic.enabled(screenAllows: false, flagOn: true), isFalse);
      expect(RangeReadLogic.enabled(screenAllows: true, flagOn: false), isFalse);
    });
  });

  group('scoring with a Range Read letter', () {
    test('right = c, wrong = m, weight = the decision pot', () {
      // Hand: decision c (pot 10), RR wrong (weight 10), decision c (pot 30).
      // accuracy = (10 + 0 + 30) / 50 = 0.8
      expect(DailyScoring.handAccuracy('cmc', const [10, 10, 30]),
          closeTo(0.8, 1e-9));
      expect(DailyScoring.isPerfect('cmc'), isFalse);
      expect(DailyScoring.isPerfect('ccc|cc'), isTrue);
    });

    test('day score with quiz letters across hands', () {
      // Hand 1 'cc' (weights 5,5) = 1.0; hand 2 'oc' + RR wrong = 'ocm'
      // (weights 10,20,20): (5 + 20 + 0)/50 = 0.5 -> mean 0.75 -> 75.0
      expect(DailyScoring.accuracy('cc|ocm', const [5, 5, 10, 20, 20]), 75.0);
    });
  });

  group('DailyChallengeResult with Range Read', () {
    final q = RangeReadQuestion(
      type: RangeReadType.also,
      action: 'call',
      actionWord: 'call',
      options: const [
        RangeReadOption('76s', 0.0),
        RangeReadOption('KQs', 0.92),
        RangeReadOption('A5o', 0.05),
      ],
      correctIndex: 1,
    );

    DailyChallengeResult build(int chosen) => DailyChallengeResult.build(
          dayKey: '2026-11-20',
          seed: 1,
          hands: [
            [_rec('c'), _rec('c')],
            [_rec('o')],
          ],
          weights: const [10, 30, 5],
          durationMs: 0,
          streets: const ['Preflop', 'Flop', 'Preflop'],
          boards: const [[], ['2♣', '3♦', '9♠'], []],
          quizzes: [
            [RangeReadAnswer(question: q, chosen: chosen, afterDecision: 0)],
            const [],
          ],
        );

    test('letter + weight inserted right after its decision', () {
      final wrong = build(0);
      expect(wrong.verdicts, 'cmc|o');
      expect(wrong.weights, [10, 10, 30, 5]);
      final right = build(1);
      expect(right.verdicts, 'ccc|o');
      expect(right.perfect, isFalse); // hand 2 is 'o'
      expect(right.score, closeTo(DailyScoring.accuracy('ccc|o', [10, 10, 30, 5]), 1e-9));
    });

    test('summary rows: quiz row sits after its decision, keeps board/street', () {
      final r = build(0);
      expect(r.spots.length, 4);
      expect(r.spots.map((s) => s.isRangeRead), [false, true, false, false]);
      expect(r.spots[1].verdict, 'm');
      expect(r.spots[1].hand, 0);
      expect(r.spots[1].street, 'Preflop');
      expect(r.spots[2].board, ['2♣', '3♦', '9♠']); // alignment kept
      expect(r.spots[2].street, 'Flop');
    });

    test('JSON round-trip keeps the question and the answer', () {
      final r = build(0);
      final back = DailyChallengeResult.fromJson('2026-11-20', r.toJson());
      expect(back.verdicts, r.verdicts);
      expect(back.weights, r.weights);
      final rr = back.spots[1].rangeRead!;
      expect(rr.chosen, 0);
      expect(rr.right, isFalse);
      expect(rr.question.options[1].hand, 'KQs');
      expect(rr.question.options[1].freq, 0.92);
      expect(rr.question.correctIndex, 1);
      expect(rr.afterDecision, 0);
    });

    test('old stored JSON without a kind still parses as decisions', () {
      final back = DailyChallengeResult.fromJson('2026-11-01', {
        'seed': 3,
        'v': 'cc|o',
        'w': [5, 5, 9],
        'spots': [
          {'hc': '9♠ 9♥', 'pos': 'LJ vs BTN', 'act': 'raise', 'rec': 'raise', 'g': 'c', 'h': 0, 'st': 'Preflop'},
          {'hc': '9♠ 9♥', 'pos': 'LJ vs BTN', 'act': 'call', 'rec': 'call', 'g': 'c', 'h': 0, 'st': 'Flop'},
          {'hc': 'AKo', 'pos': 'BTN', 'act': 'fold', 'rec': 'call', 'g': 'o', 'h': 1},
        ],
      });
      expect(back.spots.length, 3);
      expect(back.spots.every((s) => !s.isRangeRead), isTrue);
      expect(back.score, DailyScoring.accuracy('cc|o', [5, 5, 9]));
    });

    test('without quizzes the result is exactly as before', () {
      final r = DailyChallengeResult.build(
        dayKey: 'd',
        seed: 1,
        hands: [
          [_rec('c'), _rec('m')],
        ],
        weights: const [4, 8],
        durationMs: 0,
      );
      expect(r.verdicts, 'cm');
      expect(r.weights, [4, 8]);
      expect(r.spots.length, 2);
    });
  });

  test('onboarding demo runner opts out of Range Read', () {
    // The demo spawns its runner in a route that needs Firebase, so assert
    // the wiring at the source level.
    final src = File('lib/screens/onboarding/demo_challenge_step.dart')
        .readAsStringSync();
    expect(src, contains('rangeRead: false'));
  });
}
