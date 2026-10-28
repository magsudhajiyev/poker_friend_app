import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/authored_spot.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/services/authored_situation.dart';
import 'package:poker_logger/services/authored_tree_walker.dart';

/// Plays [actions] through the walker, building the same history the screen
/// does, and returns the situation line at each hero decision.
List<Situation> _play(AuthoredTree tree, List<AuthoredAction> actions,
    {String coach = 'grinder'}) {
  final walker = AuthoredTreeWalker(tree);
  final history = <SituationStep>[];
  final lines = <Situation>[];
  // Mirror the screen's initState: if the tree opens on a VILLAIN node (hero
  // isn't first to act — BB defense, flat vs an open), play the opener's
  // action(s) into history BEFORE the hero's first decision, so the coach sees
  // "BTN raised to 2BB" rather than "folds to you".
  if (!walker.isHeroTurn && !walker.isOver) {
    walker.advanceVillains();
    for (final m in walker.lastVillainMoves) {
      history.add(SituationStep(
          actor: TreeActor.villain,
          action: m.action,
          sizeBB: m.sizeBB,
          street: m.street));
    }
  }
  for (final a in actions) {
    final node = walker.current!;
    lines.add(AuthoredSituation.describe(
        tree: tree, node: node, history: history, coachId: coach));
    walker.applyHeroAction(a);
    final taken = walker.lastReroute ?? a;
    history.add(SituationStep(
      actor: TreeActor.hero,
      action: taken,
      sizeBB: switch (taken) {
        AuthoredAction.call => node.toCallBB,
        AuthoredAction.raise => node.sizingBB[AuthoredAction.raise] ?? 0,
        AuthoredAction.allin => node.sizingBB[AuthoredAction.allin] ?? 0,
        _ => 0,
      },
      street: node.street,
    ));
    for (final m in walker.lastVillainMoves) {
      history.add(SituationStep(
          actor: TreeActor.villain,
          action: m.action,
          sizeBB: m.sizeBB,
          street: m.street));
    }
    if (walker.isOver) break;
  }
  if (!walker.isOver && walker.isHeroTurn) {
    lines.add(AuthoredSituation.describe(
        tree: tree,
        node: walker.current!,
        history: history,
        coachId: coach));
  }
  return lines;
}

void main() {
  final tree = AuthoredTree.fromJson(jsonDecode(
          File('assets/authored/lj-btn-ts9c4d-99.json').readAsStringSync())
      as Map<String, dynamic>);

  test('first decision: casual intro with the real suited cards', () {
    final s = AuthoredSituation.describe(
        tree: tree, node: tree.root, history: const [], coachId: 'grinder');
    expect(s.text, contains('9♠ 9♥'));
    expect(s.text, contains('70BB deep'));
    expect(s.text, contains('lojack'));
    // The voice says the class ("99" → speakable "pocket nines").
    expect(s.spoken, contains('99'));
    expect(s.spoken, isNot(contains('♠')));
  });

  test('facing the 3-bet: reacts to the villain, no recap of the hero', () {
    final lines = _play(tree, [AuthoredAction.raise]);
    final t = lines[1].text;
    expect(t, contains('7.3BB'));
    expect(t.toLowerCase(), contains('three-bet'));
    expect(t, isNot(contains('You open')));
    expect(t, contains('12BB')); // the pot it's played into
  });

  test('flop: reads the board and what the hero flopped', () {
    final lines = _play(tree, [AuthoredAction.raise, AuthoredAction.call]);
    final t = lines[2].text;
    expect(t, contains('10♠ 9♣ 4♦'));
    expect(t, contains("You've flopped a set of nines."));
    expect(lines[2].spoken,
        contains('ten of spades, nine of clubs, four of diamonds'));
  });

  test('each coach has its own voice for the same spot', () {
    final texts = {
      for (final c in ['grinder', 'professor', 'nova'])
        AuthoredSituation.describe(
                tree: tree, node: tree.root, history: const [], coachId: c)
            .text
    };
    expect(texts.length, 3);
  });

  test('deterministic: same spot + coach → same line', () {
    final a = _play(tree, [AuthoredAction.raise, AuthoredAction.call]);
    final b = _play(tree, [AuthoredAction.raise, AuthoredAction.call]);
    expect(a.map((s) => s.text), b.map((s) => s.text));
  });

  group('hero acts SECOND preflop (BB defense / flat vs an open)', () {
    // A villain-root tree: step 1 BTN opens to 2BB, step 2 the hero (BB)
    // decides. The hero is NOT first to act — the opener must be played out
    // before the hero's first decision.
    final bbTree = AuthoredTree.fromJson({
      'id': 'bb-btn-test',
      'title': 'MTT 25BB · BB vs BTN · 3cTdJh',
      'formatLabel': 'MTT · 25BB',
      'stackBB': 25,
      'heroPosition': 'BB',
      'villainPosition': 'BTN',
      'heroCards': ['K♦', '6♣'],
      'heroHandClass': 'K6o',
      'rootId': 'n1',
      'nodes': {
        'n1': {
          'id': 'n1',
          'street': 'preflop',
          'board': <String>[],
          'actor': 'villain',
          'potBB': 1.5,
          'toCallBB': 0,
          'prompt': 'BTN open (first in)',
          'actions': ['fold', 'raise', 'allin'],
          'sizingBB': {'raise': 2.0, 'allin': 25},
          'freq': {
            'raise': {'K6o': 1.0}
          },
          'children': {'raise': 'n2'},
        },
        'n2': {
          'id': 'n2',
          'street': 'preflop',
          'board': <String>[],
          'actor': 'hero',
          'potBB': 3.5,
          'toCallBB': 2.0,
          'prompt': 'BB vs BTN open',
          'actions': ['fold', 'call', 'raise', 'allin'],
          'sizingBB': {'raise': 6.5},
          'freq': {
            'call': {'K6o': 0.5},
            'fold': {'K6o': 0.5},
          },
          'children': const <String, dynamic>{},
        },
      },
    });

    test('coach acknowledges the opener, never "folds to you"', () {
      // First hero decision line (no hero action yet).
      final first = _play(bbTree, const []);
      expect(first, isNotEmpty);
      final t = first.first.text;
      // The opener is named (coach bubble spells the seat: "the button") with
      // its size, so the hero knows a raise happened before their turn.
      expect(t.toLowerCase(), contains('button'));
      expect(t, contains('2BB'));
      // It must NOT read as if it folded to the hero / hero is first in.
      expect(t.toLowerCase(), isNot(contains('folds to you')));
      expect(t.toLowerCase(), isNot(contains('folded to you')));
      expect(t.toLowerCase(), isNot(contains('first to act')));
      // It's an OPEN, not a 3-bet / re-raise (only one preflop raise so far).
      expect(t.toLowerCase(), isNot(contains('3-bet')));
      expect(t.toLowerCase(), isNot(contains('three-bet')));
      // The hero faces a 2BB call into the 3.5BB pot.
      expect(t, contains('3.5BB'));
    });

    test('results facing label reads "BTN raised to 2BB", not "Folded to you"',
        () {
      // Build the pre-decision history the screen builds, then label it.
      final walker = AuthoredTreeWalker(bbTree);
      final history = <SituationStep>[];
      walker.advanceVillains();
      for (final m in walker.lastVillainMoves) {
        history.add(SituationStep(
            actor: TreeActor.villain,
            action: m.action,
            sizeBB: m.sizeBB,
            street: m.street));
      }
      final label =
          AuthoredSituation.facingLabel(bbTree, history, TreeStreet.preflop);
      expect(label, 'BTN raised to 2BB');
    });

    test('spoken line is bb-free and non-empty', () {
      final first = _play(bbTree, const []).first;
      expect(first.spoken, isNotEmpty);
      expect(first.spoken, isNot(contains('BB')));
    });
  });

  test('every hero node on every line gets a non-empty, bb-free spoken line',
      () {
    // Walk all hero action choices breadth-first (bounded) and check that the
    // narrator never throws and never leaves notation for the voice.
    final queue = <List<AuthoredAction>>[[]];
    var checked = 0;
    while (queue.isNotEmpty && checked < 400) {
      final path = queue.removeAt(0);
      final lines = _play(tree, path);
      for (final l in lines) {
        expect(l.text, isNotEmpty);
        expect(l.spoken, isNot(contains('BB')));
        expect(l.spoken, isNot(contains('♠')));
        checked++;
      }
      final w = AuthoredTreeWalker(tree);
      var ok = true;
      for (final a in path) {
        w.applyHeroAction(a);
        if (w.isOver) {
          ok = false;
          break;
        }
      }
      if (ok && w.isHeroTurn) {
        for (final a in w.current!.actions) {
          if (a != AuthoredAction.fold) queue.add([...path, a]);
        }
      }
    }
    expect(checked, greaterThan(10));
  });
  group('stacks', () {
    SituationStep step(TreeActor a, AuthoredAction x, double size,
            TreeStreet st) =>
        SituationStep(actor: a, action: x, sizeBB: size, street: st);
    const h = TreeActor.hero, v = TreeActor.villain;
    const pf = TreeStreet.preflop, fl = TreeStreet.flop;

    test('open, 3-bet, call: both have 7.35BB in', () {
      final r = AuthoredSituation.stacks(70, [
        step(h, AuthoredAction.raise, 2.1, pf),
        step(v, AuthoredAction.raise, 7.35, pf),
        step(h, AuthoredAction.call, 7.35, pf),
      ]);
      expect(r.hero, closeTo(62.65, 1e-9));
      expect(r.villain, closeTo(62.65, 1e-9));
    });

    test('villain 3-bet only: hero still has the open in', () {
      final r = AuthoredSituation.stacks(70, [
        step(h, AuthoredAction.raise, 2.1, pf),
        step(v, AuthoredAction.raise, 7.35, pf),
      ]);
      expect(r.hero, closeTo(67.9, 1e-9));
      expect(r.villain, closeTo(62.65, 1e-9));
    });

    test('flop check, bet, check-raise is per-street TO amounts', () {
      final r = AuthoredSituation.stacks(70, [
        step(h, AuthoredAction.raise, 2.1, pf),
        step(v, AuthoredAction.raise, 7.35, pf),
        step(h, AuthoredAction.call, 7.35, pf),
        step(h, AuthoredAction.check, 0, fl),
        step(v, AuthoredAction.raise, 8.8, fl),
        step(h, AuthoredAction.raise, 19.2, fl),
      ]);
      expect(r.hero, closeTo(70 - 7.35 - 19.2, 1e-9));
      expect(r.villain, closeTo(70 - 7.35 - 8.8, 1e-9));
    });

    test('all-in empties the stack and never goes negative', () {
      final r = AuthoredSituation.stacks(70, [
        step(h, AuthoredAction.raise, 2.1, pf),
        step(v, AuthoredAction.raise, 7.35, pf),
        step(h, AuthoredAction.call, 7.35, pf),
        step(h, AuthoredAction.allin, 62.65, fl),
        step(v, AuthoredAction.call, 62.65, fl),
      ]);
      expect(r.hero, closeTo(0, 1e-9));
      expect(r.villain, closeTo(0, 1e-9));
    });
  });

  group('HandReader', () {
    String? label(List<String> hero, List<String> board) =>
        HandReader.read(hero, board)?.label;
    test('made hands', () {
      expect(label(['9♠', '9♥'], ['10♠', '9♣', '4♦']), 'a set of nines');
      expect(label(['A♠', 'A♥'], ['10♠', '9♣', '4♦']), 'an overpair, aces');
      expect(label(['A♠', '10♥'], ['10♠', '9♣', '4♦']), 'top pair');
      expect(label(['A♠', '9♥'], ['10♠', '9♣', '4♦']), 'second pair');
      expect(label(['10♥', '9♥'], ['10♠', '9♣', '4♦']), 'two pair');
      expect(label(['Q♥', 'J♥'], ['10♠', '9♣', '8♦']), 'a straight');
      expect(label(['A♥', '2♥'], ['K♥', '9♥', '4♥']), 'a flush');
      expect(label(['9♠', '9♥'], ['10♠', '9♣', '10♦']), 'a full house');
    });
    test('draws and air (no draws on the river)', () {
      expect(label(['A♥', '2♥'], ['K♥', '9♥', '4♣']), 'a flush draw');
      expect(label(['Q♣', 'J♦'], ['10♠', '9♣', '4♦']), 'a straight draw');
      expect(label(['A♣', 'K♦'], ['10♠', '9♣', '4♦']), 'two overcards');
      expect(label(['A♥', '2♥'], ['K♥', '9♥', '4♣', '7♠', '3♦']),
          'nothing yet');
    });
    test('board warnings', () {
      final set = HandReader.read(['9♠', '9♥'], ['10♠', '9♣', '4♦', 'J♦'])!;
      expect(HandReader.boardWarning(['10♠', '9♣', '4♦', 'J♦'], set),
          'That card fills in some straights.');
      final flushy = HandReader.read(['9♠', '9♥'], ['10♦', '9♣', '4♦', 'J♦'])!;
      expect(HandReader.boardWarning(['10♦', '9♣', '4♦', 'J♦'], flushy),
          "That's three diamonds on board now.");
    });
    test('card words', () {
      expect(HandReader.cardWords('10♠'), 'ten of spades');
      expect(HandReader.cardWords('A♥'), 'ace of hearts');
    });
  });

  test('print sample commentary (review aid)', () {
    for (final coach in ['grinder', 'professor', 'nova']) {
      final lines = _play(
          tree,
          [
            AuthoredAction.raise,
            AuthoredAction.call,
            AuthoredAction.check,
            AuthoredAction.call,
            AuthoredAction.check,
            AuthoredAction.check,
          ],
          coach: coach);
      // ignore: avoid_print
      for (final l in lines) print('[$coach] ${l.text}');
    }
  });

  test('results labels: what the hero faced + plain-word actions', () {
    final walker = AuthoredTreeWalker(tree);
    final history = <SituationStep>[];
    final facing = <String>[], hero = <String>[];
    for (final a in [
      AuthoredAction.raise, // open
      AuthoredAction.call, // vs 3-bet
      AuthoredAction.check, // flop, first to act
      AuthoredAction.call, // vs flop bet
    ]) {
      final node = walker.current!;
      facing.add(AuthoredSituation.facingLabel(tree, history, node.street));
      hero.add(AuthoredSituation.actionLabel(a, node,
          firstIn: history.isEmpty));
      walker.applyHeroAction(a);
      final taken = walker.lastReroute ?? a;
      history.add(SituationStep(
          actor: TreeActor.hero,
          action: taken,
          sizeBB: switch (taken) {
            AuthoredAction.call => node.toCallBB,
            AuthoredAction.raise => node.sizingBB[AuthoredAction.raise] ?? 0,
            _ => 0,
          },
          street: node.street));
      for (final m in walker.lastVillainMoves) {
        history.add(SituationStep(
            actor: TreeActor.villain,
            action: m.action,
            sizeBB: m.sizeBB,
            street: m.street));
      }
    }
    expect(facing, [
      'Folded to you',
      'BTN 3-bet to 7.3BB',
      'First to act',
      'BTN bet 8.8BB',
    ]);
    expect(hero, ['open to 2.1BB', 'call 7.3BB', 'check', 'call 8.8BB']);
  });

  test('actionLabel: bet vs raise postflop, synthetic bet has no size', () {
    final flop = tree.nodes['n4']!; // hero first to act on the flop
    expect(AuthoredSituation.actionLabel(AuthoredAction.raise, flop), 'bet');
    final vsBet = tree.nodes['n31']!; // hero facing the 8.8BB c-bet
    expect(AuthoredSituation.actionLabel(AuthoredAction.raise, vsBet),
        'raise to 19.2BB');
  });
}
