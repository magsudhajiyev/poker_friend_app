import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/authored_tree_walker.dart';

/// A tiny 3-node tree to exercise the walker + deterministic villain:
///   n1 (hero preflop): call → n2 ; fold → terminal
///   n2 (villain flop): bet 60% / check 40% → dominant is BET → n3
///   n3 (hero flop vs bet): raise → terminal (win)
AuthoredTree _fixture() => AuthoredTree(
      id: 't',
      title: 'test',
      formatLabel: 'MTT',
      stackBB: 70,
      anteMode: true,
      heroPosition: 'LJ',
      villainPosition: 'BTN',
      heroCards: const ['9♠', '9♥'],
      heroHandClass: '99',
      rootId: 'n1',
      nodes: {
        'n1': TreeNode(
          id: 'n1',
          street: TreeStreet.preflop,
          board: const [],
          actor: TreeActor.hero,
          potBB: 11,
          toCallBB: 5,
          prompt: 'vs 3-bet',
          actions: const [AuthoredAction.fold, AuthoredAction.call],
          sizingBB: const {},
          freq: const {
            AuthoredAction.call: {'99': 0.83, 'AA': 0.0},
            AuthoredAction.fold: {'99': 0.0, 'AA': 0.0},
          },
          children: const {AuthoredAction.call: 'n2', AuthoredAction.fold: null},
        ),
        'n2': TreeNode(
          id: 'n2',
          street: TreeStreet.flop,
          board: const ['10♠', '9♣', '4♦'],
          actor: TreeActor.villain,
          potBB: 16,
          toCallBB: 0,
          prompt: 'BTN to act',
          // bet range-sum (1.4) > check range-sum (0.6) → dominant = bet(raise).
          actions: const [AuthoredAction.check, AuthoredAction.raise],
          sizingBB: const {AuthoredAction.raise: 8},
          freq: const {
            AuthoredAction.raise: {'AA': 0.8, 'KK': 0.6},
            AuthoredAction.check: {'AA': 0.2, 'KK': 0.4},
          },
          children: const {AuthoredAction.raise: 'n3', AuthoredAction.check: null},
        ),
        'n3': TreeNode(
          id: 'n3',
          street: TreeStreet.flop,
          board: const ['10♠', '9♣', '4♦'],
          actor: TreeActor.hero,
          potBB: 24,
          toCallBB: 8,
          prompt: 'vs bet',
          actions: const [
            AuthoredAction.fold,
            AuthoredAction.call,
            AuthoredAction.raise
          ],
          sizingBB: const {AuthoredAction.raise: 18},
          freq: const {
            AuthoredAction.raise: {'99': 0.875},
            AuthoredAction.call: {'99': 0.125},
            AuthoredAction.fold: {'99': 0.0},
          },
          children: const {
            AuthoredAction.raise: null,
            AuthoredAction.call: null,
            AuthoredAction.fold: null,
          },
        ),
      },
    );

void main() {
  test('hero call → villain auto-bets → hero faces flop bet', () {
    final w = AuthoredTreeWalker(_fixture());
    expect(w.isHeroTurn, isTrue);
    expect(w.current!.street, TreeStreet.preflop);

    final g = w.applyHeroAction(AuthoredAction.call);
    expect(g.grade, DrillGrade.correct); // 99 calls 83%

    // Villain (n2) auto-advanced by its dominant action (bet=raise).
    expect(w.lastVillainMoves.length, 1);
    expect(w.lastVillainMoves.first.action, AuthoredAction.raise);
    expect(w.lastVillainMoves.first.sizeBB, 8);

    // Now the hero faces the flop bet (n3).
    expect(w.isHeroTurn, isTrue);
    expect(w.current!.id, 'n3');
    expect(w.current!.board, ['10♠', '9♣', '4♦']);
  });

  test('hero check-raise ends the hand (terminal child)', () {
    final w = AuthoredTreeWalker(_fixture());
    w.applyHeroAction(AuthoredAction.call); // → n3
    final g = w.applyHeroAction(AuthoredAction.raise); // → null terminal
    expect(g.grade, DrillGrade.correct); // 99 raises 87.5%
    expect(w.isOver, isTrue);
  });

  test('hero fold preflop ends the hand immediately', () {
    final w = AuthoredTreeWalker(_fixture());
    final g = w.applyHeroAction(AuthoredAction.fold);
    expect(g.grade, DrillGrade.mistake); // 99 never folds
    expect(w.isOver, isTrue);
  });

  test('ends the hand at a hero node the hero hand cannot reach', () {
    // n3 is a hero decision where the hero hand (99) has NO frequency (the
    // solver only lists other hands there — it's a line 99 never reaches).
    // Presenting it would misgrade every action as 0% → LEAK; instead the
    // walker must end the hand after the villain advances to it.
    final tree = AuthoredTree(
      id: 't2',
      title: 'unreachable',
      formatLabel: 'MTT',
      stackBB: 50,
      anteMode: false,
      heroPosition: 'BTN',
      villainPosition: 'SB',
      heroCards: const ['K♠', 'Q♠'],
      heroHandClass: 'KQs',
      rootId: 'n1',
      nodes: {
        'n1': TreeNode(
          id: 'n1',
          street: TreeStreet.preflop,
          board: const [],
          actor: TreeActor.hero,
          potBB: 6,
          toCallBB: 2,
          prompt: 'open',
          actions: const [AuthoredAction.fold, AuthoredAction.raise],
          sizingBB: const {AuthoredAction.raise: 2.5},
          freq: const {
            AuthoredAction.raise: {'KQs': 1.0},
            AuthoredAction.fold: {'KQs': 0.0},
          },
          children: const {AuthoredAction.raise: 'n2'},
        ),
        'n2': TreeNode(
          id: 'n2',
          street: TreeStreet.flop,
          board: const ['9♥', '7♠', '2♦'],
          actor: TreeActor.villain,
          potBB: 6,
          toCallBB: 0,
          prompt: 'SB to act',
          actions: const [AuthoredAction.check],
          sizingBB: const {},
          freq: const {
            AuthoredAction.check: {'AA': 1.0},
          },
          children: const {AuthoredAction.check: 'n3'},
        ),
        // Hero flop node, but KQs is NOT in its frequency maps → unreachable.
        'n3': TreeNode(
          id: 'n3',
          street: TreeStreet.flop,
          board: const ['9♥', '7♠', '2♦'],
          actor: TreeActor.hero,
          potBB: 6,
          toCallBB: 0,
          prompt: 'vs check',
          actions: const [AuthoredAction.check, AuthoredAction.raise],
          sizingBB: const {AuthoredAction.raise: 4},
          freq: const {
            AuthoredAction.check: {'AA': 0.5},
            AuthoredAction.raise: {'AA': 0.5},
          },
          children: const {},
        ),
      },
    );
    final w = AuthoredTreeWalker(tree);
    final g = w.applyHeroAction(AuthoredAction.raise); // open → villain checks
    expect(g.grade, DrillGrade.correct); // KQs opens 100%
    // Villain advanced to n3, but KQs can't reach it → hand ends, no decision.
    expect(w.isOver, isTrue);
    expect(w.isHeroTurn, isFalse);
  });

  test('villain cycle ends the hand instead of stalling', () {
    TreeNode v(String id, String next) => TreeNode(
          id: id,
          street: TreeStreet.flop,
          board: const ['10♠', '9♣', '4♦'],
          actor: TreeActor.villain,
          potBB: 10,
          toCallBB: 0,
          prompt: 'loop',
          actions: const [AuthoredAction.check],
          sizingBB: const {},
          freq: const {
            AuthoredAction.check: {'AA': 1.0},
          },
          children: {AuthoredAction.check: next},
        );
    final tree = AuthoredTree(
      id: 'cyc',
      title: 'cycle',
      formatLabel: 'MTT',
      stackBB: 70,
      anteMode: true,
      heroPosition: 'LJ',
      villainPosition: 'BTN',
      heroCards: const ['9♠', '9♥'],
      heroHandClass: '99',
      rootId: 'a',
      nodes: {'a': v('a', 'b'), 'b': v('b', 'a')},
    );
    final w = AuthoredTreeWalker(tree)..advanceVillains();
    expect(w.isOver, isTrue);
    expect(w.isHeroTurn, isFalse);
  });

  test('round-trips through JSON', () {
    final tree = _fixture();
    final restored = AuthoredTree.fromJson(tree.toJson());
    expect(restored.nodes.length, 3);
    expect(restored.heroHandClass, '99');
    expect(restored.node('n1')!.children[AuthoredAction.call], 'n2');
    final w = AuthoredTreeWalker(restored);
    w.applyHeroAction(AuthoredAction.call);
    expect(w.current!.id, 'n3');
  });
}
