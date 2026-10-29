import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_spot.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/services/authored_spot_grader.dart';
import 'package:poker_logger/services/coach_persona.dart';

void main() {
  test('every bundled hero node x action x persona x explanation shape', () {
    final files = Directory('assets/authored')
        .listSync()
        .whereType<File>()
        .where(
            (f) => f.path.endsWith('.json') && !f.path.endsWith('days.json'));
    const shapes = [
      '',
      'Hero range is capped here so we take the pot down',
      'Flatting a suited ace in position.',
      'Flatting a suited ace in position\nATs is a suited broadway ace',
    ];
    final bad = <String>[];
    var checked = 0;
    for (final f in files) {
      final tree = AuthoredTree.fromJson(
          json.decode(f.readAsStringSync()) as Map<String, dynamic>);
      for (final node in tree.nodes.values.where((n) => n.isHero)) {
        for (final action in node.actions) {
          for (final shape in shapes) {
            final g = AuthoredSpotGrader.grade(
              AuthoredDecision(
                street: AuthoredStreet.values.byName(node.street.name),
                board: node.board,
                prompt: node.prompt,
                options: node.actions,
                best: node.actions.reduce((a, b) =>
                    node.freqOf(a, tree.heroHandClass) >=
                            node.freqOf(b, tree.heroHandClass)
                        ? a
                        : b),
                potBB: node.potBB,
                toCallBB: node.toCallBB,
                freq: node.freq,
              ),
              tree.heroHandClass,
              action,
              displayHand: tree.heroCards.join(' '),
              explanation: shape,
            );
            for (final p in [
              CoachPersonas.grinder,
              CoachPersonas.professor,
              CoachPersonas.nova
            ]) {
              for (var n = 0; n < 4; n++) {
                final t = p.compose(g, n);
                checked++;
                if (!RegExp('[.!?…]["\')”]*\$').hasMatch(t) ||
                    RegExp(r'[.!?] [a-z]').hasMatch(t) ||
                    t.contains('  ') ||
                    t.contains('\n')) {
                  bad.add('${node.id}/${action.wire}/${p.id}: $t');
                }
              }
            }
          }
        }
      }
    }
    expect(checked, greaterThan(0));
    expect(bad, isEmpty, reason: bad.take(5).join('\n'));
  });
}
