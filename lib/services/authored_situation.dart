import '../models/authored_tree.dart';

/// One action already taken in an authored hand — the commentary's history.
class SituationStep {
  final TreeActor actor;
  final AuthoredAction action;

  /// Bet/raise size (raise-to preflop, bet amount postflop); 0 when none.
  final double sizeBB;
  final TreeStreet street;

  const SituationStep({
    required this.actor,
    required this.action,
    required this.sizeBB,
    required this.street,
  });
}

/// A coach line that sets up the spot BEFORE the hero decides: [text] is
/// shown in the bubble, [spoken] is the same line written for the voice
/// (card glyphs, 'BB' and the holding spelled out).
class Situation {
  final String text;
  final String spoken;
  const Situation(this.text, this.spoken);
}

/// The coach's running commentary between decisions — casual, in the
/// persona's own voice: reacts to what the villain just did, reads each new
/// board card (what the hero now holds, what got scarier), then hands the
/// decision back. It never names the right action (that's the verdict's job)
/// and doesn't recap the hero's own move (they just made it).
///
/// Pure and deterministic — the same spot + coach always produces the same
/// line, so the voice-clip cache is shared by every player of the day.
class AuthoredSituation {
  AuthoredSituation._();

  static Situation describe({
    required AuthoredTree tree,
    required TreeNode node,
    required List<SituationStep> history,
    String coachId = '',
  }) {
    final voice = _voices[coachId] ?? _voices['grinder']!;
    final n = history.where((s) => s.actor == TreeActor.hero).length;
    final b = _Builder(tree);
    final v = tree.villainPosition;

    if (history.isEmpty) {
      b.say(_pick(voice.intro, n), {'heroPos': _posWord(tree.heroPosition)},
          depth: tree.stackBB);
    } else {
      final start = history.lastIndexWhere((s) => s.actor == TreeActor.hero);
      var street = history[start].street;
      var preflopRaises = 0;
      for (var i = 0; i <= start; i++) {
        if (history[i].street == TreeStreet.preflop && _isRaise(history[i])) {
          preflopRaises++;
        }
      }
      for (var i = start + 1; i < history.length; i++) {
        final step = history[i];
        if (step.street != street) {
          street = step.street;
          _boardBeat(b, voice, street, node.board, tree.heroCards, n + i);
        }
        if (step.actor != TreeActor.villain) continue;
        final betBefore = history
            .sublist(start, i)
            .any((s) => s.street == step.street && _isRaise(s));
        if (step.street == TreeStreet.preflop && _isRaise(step)) {
          preflopRaises++;
        }
        final pool = switch (step.action) {
          AuthoredAction.raise when step.street == TreeStreet.preflop =>
            preflopRaises == 2 ? voice.threeBet : voice.reRaise,
          AuthoredAction.raise => betBefore ? voice.raise : voice.bet,
          AuthoredAction.allin => voice.jam,
          AuthoredAction.call => voice.call,
          AuthoredAction.check => voice.checkBack,
          AuthoredAction.fold => const <String>[],
        };
        if (pool.isNotEmpty) {
          b.say(_pick(pool, n + i), {'pos': _posWord(v)},
              size: step.sizeBB);
        }
      }
      if (node.street != street) {
        _boardBeat(b, voice, node.street, node.board, tree.heroCards, n);
      }
    }

    // Hand the decision back.
    final pot = node.potBB;
    if (node.toCallBB > 0) {
      b.say(_pick(voice.facing, n), const {}, pot: pot, call: node.toCallBB);
    } else if (history.isEmpty) {
      b.say(_pick(voice.yourMove, n), const {});
    } else {
      final last = history.last;
      final checkedTo = last.actor == TreeActor.villain &&
          last.action == AuthoredAction.check &&
          last.street == node.street;
      b.say(_pick(checkedTo ? voice.checkedTo : voice.firstToAct, n),
          const {}, pot: pot);
    }
    return b.build();
  }

  // ── Results labels (past tense, compact) ─────────────────────────────

  /// What the hero was facing at a decision on [street], from the [history]
  /// BEFORE their action: 'Folded to you', 'BTN 3-bet to 7.3BB',
  /// 'BTN bet 8.8BB', 'BTN checked', or 'First to act' on a new street.
  static String facingLabel(
      AuthoredTree tree, List<SituationStep> history, TreeStreet street) {
    if (history.isEmpty) return 'Folded to you';
    final v = tree.villainPosition;
    final start = history.lastIndexWhere((s) => s.actor == TreeActor.hero);
    var preflopRaises = 0;
    for (var i = 0; i <= start; i++) {
      if (history[i].street == TreeStreet.preflop && _isRaise(history[i])) {
        preflopRaises++;
      }
    }
    String? last;
    for (var i = start + 1; i < history.length; i++) {
      final step = history[i];
      if (step.street == TreeStreet.preflop && _isRaise(step)) {
        preflopRaises++;
      }
      if (step.actor != TreeActor.villain || step.street != street) continue;
      final betBefore = history
          .sublist(start + 1, i)
          .any((s) => s.street == street && _isRaise(s));
      final heroBetThisStreet = start >= 0 &&
          history[start].street == street &&
          _isRaise(history[start]);
      final size = '${_fmt(step.sizeBB)}BB';
      last = switch (step.action) {
        AuthoredAction.check => '$v checked',
        AuthoredAction.call => '$v called',
        AuthoredAction.fold => '$v folded',
        AuthoredAction.allin => '$v all-in $size',
        AuthoredAction.raise when street == TreeStreet.preflop =>
          preflopRaises == 2
              ? '$v 3-bet to $size'
              : (preflopRaises == 3 ? '$v 4-bet to $size' : '$v raised to $size'),
        AuthoredAction.raise => (betBefore || heroBetThisStreet)
            ? '$v raised to $size'
            : '$v bet $size',
      };
    }
    return last ?? 'First to act';
  }

  /// The hero's [action] at [node] in plain poker words: 'open to 2.1BB',
  /// 'call 7.3BB', 'check', 'bet 16.2BB', 'raise to 19.2BB', 'all-in'.
  /// [firstIn] = no one has bet yet this hand (preflop raise = an open).
  static String actionLabel(AuthoredAction action, TreeNode node,
      {bool firstIn = false}) {
    final size = node.sizingBB[action];
    final amt = size == null ? '' : ' ${_fmt(size)}BB';
    return switch (action) {
      AuthoredAction.fold => 'fold',
      AuthoredAction.check => 'check',
      AuthoredAction.call =>
        node.toCallBB > 0 ? 'call ${_fmt(node.toCallBB)}BB' : 'call',
      AuthoredAction.allin => 'all-in',
      AuthoredAction.raise when node.street == TreeStreet.preflop =>
        firstIn ? 'open to${amt.isEmpty ? '' : amt}' : 'raise to$amt',
      AuthoredAction.raise =>
        node.toCallBB > 0 ? 'raise to$amt' : 'bet${amt.isEmpty ? '' : amt}',
    }
        .replaceAll(RegExp(r' to$'), '');
  }

  // ── Board beats ────────────────────────────────────────────────────────

  static void _boardBeat(_Builder b, _Voice voice, TreeStreet street,
      List<String> board, List<String> hero, int n) {
    final (from, to, pool) = switch (street) {
      TreeStreet.preflop => (0, 0, const <String>[]),
      TreeStreet.flop => (0, 3, voice.flop),
      TreeStreet.turn => (3, 4, voice.turn),
      TreeStreet.river => (4, 5, voice.river),
    };
    if (pool.isEmpty || board.length < to) return;
    b.say(_pick(pool, n), const {}, cards: board.sublist(from, to));

    final now = HandReader.read(hero, board.sublist(0, to));
    if (now == null) return;
    // Only narrate the holding when it's worth saying: a MADE hand that
    // connected with the board (→ "flopped/now got X"), or an overpair (→
    // "you have an overpair"). Announcing "two overcards", a bare draw, or
    // restating an unimproved pocket pair ("flopped nines") reads as nonsense.
    if (now.overpair) {
      // Said the same way on any street — the hero already held the pair.
      b.raw('You have ${now.label}.');
    } else if (now.made) {
      if (street == TreeStreet.flop) {
        b.raw("You've flopped ${now.label}.");
      } else {
        final before = HandReader.read(hero, board.sublist(0, from));
        if (before != null && before.made && before.rank == now.rank) {
          b.raw('Still ${now.label}.');
        } else {
          b.raw("Now you've got ${now.label}.");
        }
      }
    }
    // A scary card the hero doesn't already have covered (turn/river only;
    // boardWarning itself guards board.length < 4).
    final warn = HandReader.boardWarning(board.sublist(0, to), now);
    if (warn != null) b.raw(warn);
  }

  // ── helpers ────────────────────────────────────────────────────────────

  static String _pick(List<String> pool, int n) => pool[n % pool.length];

  static bool _isRaise(SituationStep s) =>
      s.action == AuthoredAction.raise || s.action == AuthoredAction.allin;

  static const Map<String, String> _positionWords = {
    'BTN': 'the button', 'SB': 'the small blind', 'BB': 'the big blind',
    'LJ': 'the lojack', 'HJ': 'the hijack', 'CO': 'the cutoff',
    'UTG': 'under the gun',
  };

  static String _posWord(String pos) => _positionWords[pos] ?? pos;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// Remaining stacks after [history], from a [startBB] effective stack.
  /// Every solver size is a TO-amount for its street (raise-to, bet, and an
  /// all-in = the whole remaining stack at the street's start); a call
  /// matches the opponent's street total; a check adds nothing.
  static ({double hero, double villain}) stacks(
      double startBB, List<SituationStep> history) {
    var heroIn = 0.0, villainIn = 0.0; // committed on earlier streets
    var heroSt = 0.0, villainSt = 0.0; // committed on the current street
    TreeStreet? street;
    for (final step in history) {
      if (step.street != street) {
        heroIn += heroSt;
        villainIn += villainSt;
        heroSt = 0;
        villainSt = 0;
        street = step.street;
      }
      final hero = step.actor == TreeActor.hero;
      final mine = hero ? heroSt : villainSt;
      final theirs = hero ? villainSt : heroSt;
      final remaining = startBB - (hero ? heroIn : villainIn);
      final to = switch (step.action) {
        AuthoredAction.call => theirs,
        AuthoredAction.raise || AuthoredAction.allin => step.sizeBB,
        _ => mine,
      };
      final next = to.clamp(mine, remaining).toDouble();
      if (hero) {
        heroSt = next;
      } else {
        villainSt = next;
      }
    }
    return (
      hero: startBB - heroIn - heroSt,
      villain: startBB - villainIn - villainSt,
    );
  }
}

/// Renders template lines into the display text and the spoken text.
///
/// Tokens: {pos}/{Pos} villain ("the button"), {heroPos}, {depth}, {hand}
/// (the hero's cards), {size}/{pot}/{call}/{depth} (amounts), {cards} (flop),
/// {card} (turn/river card).
class _Builder {
  final AuthoredTree tree;
  final _text = <String>[];
  final _spoken = <String>[];
  _Builder(this.tree);

  void raw(String s) {
    _text.add(s);
    _spoken.add(s);
  }

  void say(String template, Map<String, String> vars,
      {double? size,
      double? pot,
      double? call,
      double? depth,
      List<String>? cards}) {
    String render(bool spoken) {
      String amt(double v) => spoken
          ? '${AuthoredSituation._fmt(v)} big blinds'
          : '${AuthoredSituation._fmt(v)}BB';
      String cardList(List<String> c) => spoken
          ? c.map(HandReader.cardWords).join(', ')
          : c.join(' ');
      var out = template;
      vars.forEach((k, val) {
        out = out
            .replaceAll('{$k}', val)
            .replaceAll('{${k[0].toUpperCase()}${k.substring(1)}}',
                val.isEmpty ? val : '${val[0].toUpperCase()}${val.substring(1)}');
      });
      out = out.replaceAll(
          '{hand}', spoken ? tree.heroHandClass : tree.heroCards.join(' '));
      if (size != null) out = out.replaceAll('{size}', amt(size));
      if (pot != null) out = out.replaceAll('{pot}', amt(pot));
      if (call != null) out = out.replaceAll('{call}', amt(call));
      if (depth != null) out = out.replaceAll('{depth}', amt(depth));
      if (cards != null) {
        out = out
            .replaceAll('{cards}', cardList(cards))
            .replaceAll('{card}', cardList(cards));
      }
      return out;
    }

    _text.add(render(false));
    _spoken.add(render(true));
  }

  Situation build() => Situation(_text.join(' '), _spoken.join(' '));
}

/// A persona's phrase pools. Lines react and set the scene — never advise.
class _Voice {
  final List<String> intro, yourMove;
  final List<String> threeBet, reRaise, bet, raise, jam, call, checkBack;
  final List<String> flop, turn, river;
  final List<String> facing, checkedTo, firstToAct;
  const _Voice({
    required this.intro,
    required this.yourMove,
    required this.threeBet,
    required this.reRaise,
    required this.bet,
    required this.raise,
    required this.jam,
    required this.call,
    required this.checkBack,
    required this.flop,
    required this.turn,
    required this.river,
    required this.facing,
    required this.checkedTo,
    required this.firstToAct,
  });
}

const Map<String, _Voice> _voices = {
  // Duke — old-school Vegas grinder.
  'grinder': _Voice(
    intro: [
      "Alright, kid. {depth} deep, it folds to you in {heroPos} and you're looking at {hand}.",
      'Folds around to you in {heroPos}, kid. {depth} deep, holding {hand}.',
    ],
    yourMove: ["What's it gonna be?", 'Your move, kid.'],
    threeBet: [
      "{Pos} doesn't like it. Three-bet to {size}.",
      'Here we go — {pos} comes over the top to {size}.',
    ],
    reRaise: ["{Pos} isn't backing down. Re-raise to {size}."],
    bet: ['{Pos} takes a stab, {size}.', '{Pos} fires {size} at it.'],
    raise: ['Whoa — {pos} raises you to {size}. Somebody woke up.',
      'Uh-oh. {Pos} raises to {size}.'],
    jam: ['{Pos} shoves. All-in, {size}.',
      '{Pos} puts you to the test — all-in for {size}.'],
    call: ['{Pos} just calls.', '{Pos} flats. No fireworks yet.'],
    checkBack: ['{Pos} checks it back.', '{Pos} taps the table behind you.'],
    flop: ['Flop comes {cards}.', "Here's your flop: {cards}."],
    turn: ["Turn's the {card}.", 'The {card} hits the turn.'],
    river: ['River: the {card}.', 'And the river brings the {card}.'],
    facing: ["{pot} in the middle, {call} to you. What's it gonna be?",
      "It's {call} to stay in a {pot} pot. Your move, kid."],
    checkedTo: ["Checked to you with {pot} out there. What d'you do?"],
    firstToAct: ["{pot} in the pot and it's on you, kid.",
      "You're first in, {pot} in the middle. What's the play?"],
  ),
  // Prof. Vega — dry theorist.
  'professor': _Voice(
    intro: [
      '{depth} effective. Action folds to you in {heroPos}, holding {hand}.',
      'We begin in {heroPos}, {depth} deep, with {hand}. Folded to you.',
    ],
    yourMove: ['Your decision.', 'Proceed.'],
    threeBet: ['{Pos} responds with a three-bet to {size}.',
      'A three-bet from {pos}: {size}. Noted.'],
    reRaise: ['{Pos} escalates again, to {size}.'],
    bet: ['{Pos} bets {size}.', '{Pos} elects to bet, {size}.'],
    raise: ['{Pos} raises to {size}. The range narrows considerably.',
      'A raise from {pos}, to {size}.'],
    jam: ['{Pos} commits the stack: all-in for {size}.'],
    call: ['{Pos} calls.', '{Pos} continues with a call.'],
    checkBack: ['{Pos} declines to bet.', '{Pos} checks behind.'],
    flop: ['The flop: {cards}.', 'Observe the flop: {cards}.'],
    turn: ['The turn is the {card}.', 'Turn card: the {card}.'],
    river: ['The river: the {card}.', 'Final card: the {card}.'],
    facing: ['The pot is {pot}; {call} to call. Your decision.',
      'Price check: {call} into a {pot} pot. Proceed.'],
    checkedTo: ['Checked to you. {pot} in the pot. Your decision.'],
    firstToAct: ['{pot} in the pot, and you act first.',
      'You are first to act with {pot} in the pot.'],
  ),
  // Nova — high-energy hype coach.
  'nova': _Voice(
    intro: [
      "Okay! {depth} deep, it folds to you in {heroPos} and you've got {hand}!",
      "Here we go! Folds to you in {heroPos}, {depth} deep, with {hand} in hand!",
    ],
    yourMove: ["What's the move?", 'Show me what you got!'],
    threeBet: ['Ooh, {pos} fights back! Three-bet to {size}!',
      '{Pos} wants a battle — three-bet to {size}!'],
    reRaise: ["{Pos} isn't done! Re-raise to {size}!"],
    bet: ['{Pos} fires {size}!', '{Pos} goes for it — {size}!'],
    raise: ['Whoa, {pos} raises to {size}! Things just got spicy!',
      '{Pos} hits you with a raise to {size}!'],
    jam: ["ALL-IN! {Pos} shoves for {size}!",
      'Big moment — {pos} moves all-in for {size}!'],
    call: ['{Pos} calls — let\'s keep going!', '{Pos} sticks around!'],
    checkBack: ['{Pos} checks it back!', '{Pos} slows down and checks!'],
    flop: ['Flop time: {cards}!', 'Here comes the flop — {cards}!'],
    turn: ['Turn card: the {card}!', 'The {card} on the turn!'],
    river: ['River time — the {card}!', 'Last card: the {card}!'],
    facing: ['{pot} in the pot, {call} to you — what\'s the move?',
      "It's {call} to call into {pot}. You've got this — decide!"],
    checkedTo: ['Checked to you with {pot} out there — your call!'],
    firstToAct: ["You're first to act, {pot} in the middle — let's go!",
      "{pot} pot, all eyes on you!"],
  ),
};

/// What the hero holds on a board — coarse, honest labels for commentary
/// ("a set of nines", "top pair", "a flush draw"). Pure; not an equity
/// engine. [rank] orders categories (higher = stronger) so the coach can
/// say "still" vs "now".
class HandRead {
  final int rank;
  final String label;
  final bool madeStraight, madeFlush;

  /// True only for a genuine MADE hand the hero connected with the board (a
  /// pair using a board card, two pair, set/trips, straight, flush, full
  /// house, quads). False for overcards, draw-only, and an unimproved pocket
  /// pair (over/under the board) — the coach should NOT announce "you've
  /// flopped X" for those (you didn't make a new hand with the board).
  final bool made;

  /// A pocket pair over the board (strong, but not "flopped" — the coach
  /// phrases it as "You have an overpair" rather than "You've flopped…").
  final bool overpair;

  const HandRead(this.rank, this.label,
      {this.madeStraight = false,
      this.madeFlush = false,
      this.made = true,
      this.overpair = false});
}

class HandReader {
  HandReader._();

  static const Map<String, int> _ranks = {
    '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    '10': 10, 'T': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14,
  };
  static const Map<int, String> _single = {
    2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven',
    8: 'eight', 9: 'nine', 10: 'ten', 11: 'jack', 12: 'queen', 13: 'king',
    14: 'ace',
  };
  static const Map<int, String> _plural = {
    2: 'twos', 3: 'threes', 4: 'fours', 5: 'fives', 6: 'sixes',
    7: 'sevens', 8: 'eights', 9: 'nines', 10: 'tens', 11: 'jacks',
    12: 'queens', 13: 'kings', 14: 'aces',
  };
  static const Map<String, String> _suitWords = {
    '♠': 'spades', '♥': 'hearts', '♦': 'diamonds', '♣': 'clubs',
  };

  static (int, String)? _parse(String c) {
    if (c.length < 2) return null;
    final r = _ranks[c.substring(0, c.length - 1)];
    return r == null ? null : (r, c.substring(c.length - 1));
  }

  /// '10♠' → 'ten of spades'.
  static String cardWords(String c) {
    final p = _parse(c);
    if (p == null) return c;
    return '${_single[p.$1]} of ${_suitWords[p.$2] ?? p.$2}';
  }

  /// Hero's holding on [board] (3–5 cards), or null when unparsable / no
  /// board yet.
  static HandRead? read(List<String> hero, List<String> board) {
    if (hero.length != 2 || board.length < 3) return null;
    final h = [for (final c in hero) _parse(c)];
    final bd = [for (final c in board) _parse(c)];
    if (h.contains(null) || bd.contains(null)) return null;
    final hr = [for (final c in h) c!.$1];
    final br = [for (final c in bd) c!.$1];
    final all = [...h, ...bd].map((c) => c!).toList();
    final river = board.length >= 5;

    final counts = <int, int>{};
    for (final c in all) {
      counts[c.$1] = (counts[c.$1] ?? 0) + 1;
    }
    final suitCounts = <String, int>{};
    for (final c in all) {
      suitCounts[c.$2] = (suitCounts[c.$2] ?? 0) + 1;
    }
    final heroSuits = {for (final c in h) c!.$2};

    // Straight / straight draw, using at least one hole card.
    final uniq = {...counts.keys, if (counts.containsKey(14)) 1};
    bool windowHas(int lo, int need) {
      var have = 0;
      var usesHero = false;
      for (var r = lo; r < lo + 5; r++) {
        if (uniq.contains(r)) {
          have++;
          if (hr.contains(r) || (r == 1 && hr.contains(14))) usesHero = true;
        }
      }
      return have >= need && usesHero;
    }

    final straight = [for (var lo = 1; lo <= 10; lo++) lo].any(
        (lo) => windowHas(lo, 5));
    final straightDraw = !river &&
        [for (var lo = 1; lo <= 10; lo++) lo].any((lo) => windowHas(lo, 4));

    final flushSuit = suitCounts.entries
        .where((e) => e.value >= 5 && heroSuits.contains(e.key))
        .isNotEmpty;
    final flushDraw = !river &&
        suitCounts.entries
            .any((e) => e.value == 4 && heroSuits.contains(e.key));

    final pocket = hr[0] == hr[1];
    final heroCounts = [for (final r in hr) counts[r]!];
    final quads = hr.any((r) => counts[r] == 4);
    final trips = hr.any((r) => counts[r]! >= 3);
    final pairedHeroRanks = {
      for (final r in hr)
        if (br.contains(r)) r
    };
    final fullHouse = trips &&
        counts.entries.where((e) => e.value >= 2).length >= 2;

    final topBoard = br.reduce((a, b) => a > b ? a : b);
    final boardDistinct = br.toSet().toList()..sort((a, b) => b - a);

    String draws() => [
          if (flushDraw) 'a flush draw',
          if (straightDraw && !straight) 'a straight draw',
        ].join(' and ');

    if (quads) return const HandRead(9, 'quads');
    if (fullHouse) return const HandRead(8, 'a full house');
    if (flushSuit) return const HandRead(7, 'a flush', madeFlush: true);
    if (straight) {
      return const HandRead(6, 'a straight', madeStraight: true);
    }
    if (pocket && heroCounts[0] >= 3) {
      return HandRead(5, 'a set of ${_plural[hr[0]]}');
    }
    if (trips) {
      final r = hr.firstWhere((r) => counts[r]! >= 3);
      return HandRead(5, 'trip ${_plural[r]}');
    }
    String withDraw(String s) {
      final d = draws();
      return d.isEmpty ? s : '$s plus $d';
    }

    if (!pocket && pairedHeroRanks.length == 2) {
      return HandRead(4, withDraw('two pair'));
    }
    if (pocket && hr[0] > topBoard) {
      // Overpair: a strong made hand worth mentioning, but the hero already
      // HAD the pair preflop — it wasn't "flopped" (see the `made` gate, which
      // uses a non-"flopped" phrasing for this).
      return HandRead(3, withDraw('an overpair, ${_plural[hr[0]]}'),
          made: false, overpair: true);
    }
    if (pairedHeroRanks.isNotEmpty) {
      // Paired a BOARD card — genuinely connected on this street.
      final r = pairedHeroRanks.first;
      final idx = boardDistinct.indexOf(r);
      final label = idx == 0
          ? 'top pair'
          : (idx == 1 ? 'second pair' : 'a weak pair');
      return HandRead(idx == 0 ? 3 : 2, withDraw(label));
    }
    if (pocket) {
      // Underpair: already a pair preflop, didn't connect — not "flopped".
      return HandRead(2, withDraw('${_plural[hr[0]]}, under the top card'),
          made: false);
    }
    final d = draws();
    if (d.isNotEmpty) return HandRead(1, d, made: false);
    if (hr.every((r) => r > topBoard)) {
      return const HandRead(0, 'two overcards', made: false);
    }
    return const HandRead(0, 'nothing yet', made: false);
  }

  /// A heads-up about a scary new board (paired / flush or straight now
  /// possible) when the hero isn't already holding that or better.
  static String? boardWarning(List<String> board, HandRead hero) {
    final cards = [for (final c in board) _parse(c)];
    if (cards.contains(null) || board.length < 4) return null;
    final ranks = [for (final c in cards) c!.$1];
    final last = cards.last!;
    final suitCount = cards.where((c) => c!.$2 == last.$2).length;
    if (suitCount >= 3 && !hero.madeFlush && hero.rank < 7) {
      return "That's three ${_suitWords[last.$2]} on board now.";
    }
    if (ranks.where((r) => r == last.$1).length >= 2 && hero.rank < 8) {
      return 'That card pairs the board.';
    }
    // Straight possible: 3 board ranks inside a 5-rank window incl. the new card.
    final uniq = {...ranks, if (ranks.contains(14)) 1};
    final newR = last.$1;
    final opens = [for (var lo = 1; lo <= 10; lo++) lo].any((lo) {
      if (newR < lo || newR >= lo + 5) return false;
      return [for (var r = lo; r < lo + 5; r++) r]
              .where(uniq.contains)
              .length >=
          3;
    });
    if (opens && !hero.madeStraight && hero.rank < 6) {
      return 'That card fills in some straights.';
    }
    return null;
  }
}
