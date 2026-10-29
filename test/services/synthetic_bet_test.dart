import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/authored_tree_walker.dart';

TreeNode _node({
  required List<AuthoredAction> actions,
  required double pot,
  Map<AuthoredAction, double> sizing = const {},
}) =>
    TreeNode(
      id: 'x',
      street: TreeStreet.river,
      board: const [],
      actor: TreeActor.hero,
      potBB: pot,
      toCallBB: 0,
      prompt: '',
      actions: actions,
      sizingBB: sizing,
      freq: const {},
      children: const {},
    );

/// Finds a river hero node where the synthetic Bet is offered and returns a
/// walker standing on it (replaying a path of hero actions).
AuthoredTreeWalker? _reach(AuthoredTree tree) {
  AuthoredTreeWalker? found;
  void dfs(List<AuthoredAction> path) {
    if (found != null || path.length > 7) return;
    final w = AuthoredTreeWalker(tree)..advanceVillains();
    for (final a in path) {
      if (!w.isHeroTurn) return;
      w.applyHeroAction(a);
    }
    if (!w.isHeroTurn) return;
    final n = w.current!;
    if (n.street == TreeStreet.river && syntheticBetSizeBB(n) != null) {
      found = w;
      return;
    }
    for (final a in n.actions) {
      if (a != AuthoredAction.fold) dfs([...path, a]);
    }
  }

  dfs([]);
  return found;
}

void main() {
  const check = AuthoredAction.check;
  const allin = AuthoredAction.allin;

  group('syntheticBetSizeBB', () {
    test('is 1/3 pot rounded to 0.1BB', () {
      final n =
          _node(actions: [check, allin], pot: 16.7, sizing: {allin: 42.9});
      expect(syntheticBetSizeBB(n), 5.6);
    });

    test('tiny pot uses the 1BB minimum', () {
      final n = _node(actions: [check, allin], pot: 1.5, sizing: {allin: 20});
      expect(syntheticBetSizeBB(n), 1.0);
    });

    test('hidden when the 1BB minimum reaches the all-in size', () {
      final n = _node(actions: [check, allin], pot: 1.5, sizing: {allin: 1});
      expect(syntheticBetSizeBB(n), isNull);
    });

    test('hidden when it reaches the all-in size', () {
      final n = _node(actions: [check, allin], pot: 30, sizing: {allin: 10});
      expect(syntheticBetSizeBB(n), isNull);
    });

    test('hidden when check is missing or a real raise exists', () {
      expect(syntheticBetSizeBB(_node(actions: [allin], pot: 20)), isNull);
      expect(
          syntheticBetSizeBB(
              _node(actions: [check, AuthoredAction.raise], pot: 20)),
          isNull);
    });
  });

  group('real bundled trees', () {
    late AuthoredTree tree;
    setUpAll(() {
      // Same solved btn-co-acjd4d tree, re-dealt as ATs (the hand the bug was
      // reported with): AJs never reaches the check/allin-only river nodes.
      final j = json.decode(
              File('assets/authored/btn-co-acjd4d-ajs.json').readAsStringSync())
          as Map<String, dynamic>;
      j['heroHandClass'] = 'ATs';
      tree = AuthoredTree.fromJson(j);
    });

    AuthoredTreeWalker? reachRiverCheckAllin() => _reach(tree);

    test('synthetic Bet: sized, graded LEAK, reroutes along the solver line',
        () {
      final w = reachRiverCheckAllin();
      expect(w, isNotNull, reason: 'tree has a check/allin-only river node');
      final n = w!.current!;
      final size = syntheticBetSizeBB(n)!;
      expect(size, (n.potBB / 3 * 10).round() / 10);
      expect(size, lessThan(n.sizingBB[allin]!));

      final control = reachRiverCheckAllin()!..applyHeroAction(allin);
      final g = w.applyHeroAction(AuthoredAction.raise);

      expect(g.grade, DrillGrade.mistake);
      expect(w.lastReroute, allin);
      // Continuation is exactly the solver's all-in branch, so pot/stack match
      // the solver path (the synthetic bet is replaced, not added).
      expect(w.current?.id, control.current?.id);
      expect([for (final m in w.lastVillainMoves) (m.action, m.sizeBB)],
          [for (final m in control.lastVillainMoves) (m.action, m.sizeBB)]);
    });
  });
}
