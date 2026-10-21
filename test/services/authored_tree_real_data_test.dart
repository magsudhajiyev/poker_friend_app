import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/authored_tree_walker.dart';

/// Validates the REAL exported tree (assets/authored/lj-btn-ts9c4d-99.json —
/// the same doc uploaded to Firestore) end-to-end: structure, linking, the
/// deterministic villain, and full hero lines from preflop to terminal.
void main() {
  late AuthoredTree tree;

  setUpAll(() {
    final raw =
        File('assets/authored/lj-btn-ts9c4d-99.json').readAsStringSync();
    tree = AuthoredTree.fromJson(json.decode(raw) as Map<String, dynamic>);
  });

  test('tree structure: 66 nodes, hero 99, root is the open decision', () {
    expect(tree.nodes.length, 66);
    expect(tree.heroHandClass, '99');
    expect(tree.heroCards, ['9♠', '9♥']);
    expect(tree.root.isHero, isTrue);
    expect(tree.root.street, TreeStreet.preflop);
  });

  test('main line: open → vs 3-bet → flop check → vs c-bet check-raise', () {
    final w = AuthoredTreeWalker(tree);

    // 1) Preflop open. 99 opens 100% → BEST.
    expect(w.current!.id, 'n1');
    var g = w.applyHeroAction(AuthoredAction.raise);
    expect(g.grade, DrillGrade.correct);
    // Villain (BTN) must 3-BET (the solved line), not fold its range argmax.
    expect(w.lastVillainMoves.single.action, AuthoredAction.raise);
    expect(w.lastVillainMoves.single.sizeBB, 7.35);

    // 2) Facing the 3-bet. 99 calls 83% → BEST.
    expect(w.current!.id, 'n3');
    g = w.applyHeroAction(AuthoredAction.call);
    expect(g.grade, DrillGrade.correct);

    // 3) Flop T94 — hero first to act, checks (range checks ~100%).
    expect(w.current!.id, 'n4');
    expect(w.current!.board, ['10♠', '9♣', '4♦']);
    g = w.applyHeroAction(AuthoredAction.check);
    expect(g.grade, DrillGrade.correct);
    // BTN's deterministic flop action decides the branch: bet → hero faces
    // the c-bet (n31); check → turn (n6). Either is valid data-driven play.
    expect(['n31', 'n6'].contains(w.current!.id), isTrue,
        reason: 'BTN must bet (n31) or check (n6), got ${w.current!.id}');

    if (w.current!.id == 'n31') {
      // 4) Check-raise the c-bet: 99 raises 87.5% → BEST, BTN responds.
      g = w.applyHeroAction(AuthoredAction.raise);
      expect(g.grade, DrillGrade.correct);
      // BTN continues along a solved branch (call→turn n57 / jam n65) or the
      // hand ends if its deterministic pick is fold.
      // Whatever happens, the walk stays consistent:
      expect(w.isOver || w.isHeroTurn, isTrue);
    }
  });

  test('passive line reaches turn and river with growing board', () {
    final w = AuthoredTreeWalker(tree);
    w.applyHeroAction(AuthoredAction.raise); // open
    w.applyHeroAction(AuthoredAction.call); // vs 3-bet
    w.applyHeroAction(AuthoredAction.check); // flop

    // Walk passively (check/call) until the hand ends; the board must grow
    // monotonically and every node must be a hero decision.
    var sawTurn = false;
    var sawRiver = false;
    var guard = 0;
    while (!w.isOver && guard++ < 10) {
      final n = w.current!;
      expect(n.isHero, isTrue);
      if (n.street == TreeStreet.turn) {
        sawTurn = true;
        expect(n.board.length, 4);
        expect(n.board[3], 'J♦');
      }
      if (n.street == TreeStreet.river) {
        sawRiver = true;
        expect(n.board.length, 5);
        expect(n.board[4], '2♥');
      }
      // Prefer check, else call, else first action.
      final a = n.actions.contains(AuthoredAction.check)
          ? AuthoredAction.check
          : (n.actions.contains(AuthoredAction.call)
              ? AuthoredAction.call
              : n.actions.first);
      w.applyHeroAction(a);
    }
    expect(w.isOver, isTrue);
    // A passive line in this tree must at least reach the turn.
    expect(sawTurn || sawRiver, isTrue);
  });

  test('hero fold preflop ends the hand as a leak', () {
    final w = AuthoredTreeWalker(tree);
    final g = w.applyHeroAction(AuthoredAction.fold);
    expect(g.grade, DrillGrade.mistake); // 99 never open-folds
    expect(w.isOver, isTrue);
  });

  test('every linked child id exists and streets never go backwards', () {
    const order = {
      TreeStreet.preflop: 0,
      TreeStreet.flop: 1,
      TreeStreet.turn: 2,
      TreeStreet.river: 3,
    };
    for (final n in tree.nodes.values) {
      for (final childId in n.children.values) {
        if (childId == null) continue;
        final c = tree.nodes[childId];
        expect(c, isNotNull, reason: '${n.id} links to missing $childId');
        expect(order[c!.street]! >= order[n.street]!, isTrue,
            reason: '${n.id}(${n.street}) → ${c.id}(${c.street})');
      }
    }
  });
}
