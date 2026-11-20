import '../models/authored_tree.dart';
import 'daily_coach_lines_service.dart';

/// RANGE READ — the coach's "which of these hands would ALSO/NOT <action>
/// here?" question about the action the player just picked, on an authored
/// game-tree Daily Challenge hand. Pure (no Flutter). NOT related to the
/// `spot_quiz` notification feature.
///
/// Scoring encoding: an answer is ONE extra verdict letter in its hand's group
/// right after the decision it follows ('c' right / 'm' wrong), weighted with
/// that decision's pot — so the server scoring needs no change.
enum RangeReadType { also, not }

/// One answer option: a hand class and its solver frequency for the action.
class RangeReadOption {
  final String hand; // 'KQs'
  final double freq; // 0..1

  /// A concrete live combo of [hand] as glyph cards ('K♠','Q♠'); empty on
  /// old stored results.
  final List<String> cards;
  const RangeReadOption(this.hand, this.freq, {this.cards = const []});

  Map<String, dynamic> toJson() => {
        'h': hand,
        'f': freq,
        if (cards.isNotEmpty) 'c': cards,
      };
  factory RangeReadOption.fromJson(Map<String, dynamic> j) => RangeReadOption(
        j['h']?.toString() ?? '',
        (j['f'] as num?)?.toDouble() ?? 0,
        cards: [
          for (final c in (j['c'] as List? ?? const [])) c.toString(),
        ],
      );
}

class RangeReadQuestion {
  final RangeReadType type;

  /// Wire name of the picked action ('call', 'raise', ...).
  final String action;

  /// Display verb ('call', 'bet', 'raise', 'jam', 'fold', 'check').
  final String actionWord;
  final List<RangeReadOption> options; // always 3
  final int correctIndex;

  const RangeReadQuestion({
    required this.type,
    required this.action,
    required this.actionWord,
    required this.options,
    required this.correctIndex,
  });

  Map<String, dynamic> toJson() => {
        't': type.name,
        'a': action,
        'w': actionWord,
        'o': [for (final o in options) o.toJson()],
        'c': correctIndex,
      };

  factory RangeReadQuestion.fromJson(Map<String, dynamic> j) =>
      RangeReadQuestion(
        type: j['t'] == 'not' ? RangeReadType.not : RangeReadType.also,
        action: j['a']?.toString() ?? '',
        actionWord: j['w']?.toString() ?? '',
        options: [
          for (final o in (j['o'] as List? ?? const []))
            if (o is Map) RangeReadOption.fromJson(o.cast<String, dynamic>()),
        ],
        correctIndex: (j['c'] as num?)?.toInt() ?? 0,
      );
}

/// The player's answer to a [RangeReadQuestion].
class RangeReadAnswer {
  final RangeReadQuestion question;
  final int chosen;

  /// 0-based index (within its hand) of the decision this question followed.
  final int afterDecision;

  const RangeReadAnswer({
    required this.question,
    required this.chosen,
    required this.afterDecision,
  });

  bool get right => chosen == question.correctIndex;

  /// The verdict letter this answer contributes to the day score.
  String get letter => right ? 'c' : 'm';

  Map<String, dynamic> toJson() => {
        'q': question.toJson(),
        'x': chosen,
        'ad': afterDecision,
      };

  factory RangeReadAnswer.fromJson(Map<String, dynamic> j) => RangeReadAnswer(
        question: RangeReadQuestion.fromJson(
            ((j['q'] as Map?) ?? const {}).cast<String, dynamic>()),
        chosen: (j['x'] as num?)?.toInt() ?? 0,
        afterDecision: (j['ad'] as num?)?.toInt() ?? 0,
      );
}

/// Outcome of [RangeReadLogic.plan] for one decision.
class RangeReadPlan {
  /// Non-null when a question CAN be built here (the decision is eligible).
  final RangeReadQuestion? question;

  /// Whether to actually ask it at this decision.
  final bool ask;
  const RangeReadPlan(this.question, this.ask);
  bool get eligible => question != null;
}

class RangeReadLogic {
  RangeReadLogic._();

  /// A hand "does" the action with at least this frequency.
  static const double strong = 0.65;

  /// A hand "does not" do the action at or below this frequency.
  static const double weak = 0.10;

  /// Max verdict letters per hand (rules cap: 5 hands x 10 + 4 = 54 chars).
  static const int maxLettersPerHand = 10;

  /// Feature on only when the screen allows it AND the remote flag is on.
  static bool enabled({required bool screenAllows, required bool flagOn}) =>
      screenAllows && flagOn;

  // ── Combos / blockers ──────────────────────────────────────────────────
  static const _suits = ['s', 'h', 'd', 'c'];
  static const _glyphSuit = {'♠': 's', '♥': 'h', '♦': 'd', '♣': 'c'};

  /// Dead-card keys ('Ts') for glyph cards like '10♠'.
  static Set<String> deadKeys(Iterable<String> glyphCards) {
    final out = <String>{};
    for (final c in glyphCards) {
      if (c.length < 2) continue;
      final rank = c.substring(0, c.length - 1).replaceAll('10', 'T');
      final suit = _glyphSuit[c.substring(c.length - 1)];
      if (suit != null) out.add('$rank$suit');
    }
    return out;
  }

  /// Number of combos of [handClass] ('AKs','99','76o') not using [dead].
  static int liveCombos(String handClass, Set<String> dead) {
    if (handClass.length < 2) return 0;
    final a = handClass[0], b = handClass[1];
    bool live(String r, String s) => !dead.contains('$r$s');
    var n = 0;
    if (a == b) {
      for (var i = 0; i < 4; i++) {
        for (var j = i + 1; j < 4; j++) {
          if (live(a, _suits[i]) && live(a, _suits[j])) n++;
        }
      }
    } else if (handClass.endsWith('s')) {
      for (final s in _suits) {
        if (live(a, s) && live(b, s)) n++;
      }
    } else {
      for (final s1 in _suits) {
        for (final s2 in _suits) {
          if (s1 != s2 && live(a, s1) && live(b, s2)) n++;
        }
      }
    }
    return n;
  }

  static const _suitGlyph = {'s': '♠', 'h': '♥', 'd': '♦', 'c': '♣'};

  /// All live combos of [handClass] as glyph-card pairs, in a stable order.
  static List<List<String>> _liveList(String handClass, Set<String> dead) {
    if (handClass.length < 2) return const [];
    final a = handClass[0], b = handClass[1];
    final out = <List<String>>[];
    void add(String s1, String s2) {
      if (dead.contains('$a$s1') || dead.contains('$b$s2')) return;
      out.add(['$a${_suitGlyph[s1]}', '$b${_suitGlyph[s2]}']);
    }

    if (a == b) {
      for (var i = 0; i < 4; i++) {
        for (var j = i + 1; j < 4; j++) {
          add(_suits[i], _suits[j]);
        }
      }
    } else if (handClass.endsWith('s')) {
      for (final s in _suits) {
        add(s, s);
      }
    } else {
      for (final s1 in _suits) {
        for (final s2 in _suits) {
          if (s1 != s2) add(s1, s2);
        }
      }
    }
    return out;
  }

  /// Deterministic LIVE combo of [handClass] (glyph cards), picked by the
  /// hash of [seed]. Empty when no combo avoids [dead].
  static List<String> comboFor(
      String handClass, Set<String> dead, String seed) {
    final live = _liveList(handClass, dead);
    return live.isEmpty ? const [] : live[_h(seed) % live.length];
  }

  /// Display verb for the picked action at [node].
  static String wordFor(AuthoredAction a, TreeNode node) => switch (a) {
        AuthoredAction.fold => 'fold',
        AuthoredAction.check => 'check',
        AuthoredAction.call => 'call',
        AuthoredAction.allin => 'jam',
        AuthoredAction.raise =>
          (node.street != TreeStreet.preflop && node.toCallBB <= 0)
              ? 'bet'
              : 'raise',
      };

  // ── Question building ──────────────────────────────────────────────────
  static int _h(String s) => DailyCoachLinesService.stableHash(s);

  /// Builds the question for [picked] at [node], or null when none can be
  /// built (not enough clearly-in / clearly-out hands). Deterministic in
  /// [seed].
  static RangeReadQuestion? build({
    required AuthoredTree tree,
    required TreeNode node,
    required AuthoredAction picked,
    required String seed,
  }) {
    final dead = deadKeys([...tree.heroCards, ...node.board]);
    final pool = <String>{
      for (final g in node.freq.values) ...g.keys,
    }
      ..remove(tree.heroHandClass)
      ..removeWhere((hc) => liveCombos(hc, dead) == 0);
    final strongs = [
      for (final hc in pool)
        if (node.freqOf(picked, hc) >= strong) hc
    ]..sort();
    final weaks = [
      for (final hc in pool)
        if (node.freqOf(picked, hc) <= weak) hc
    ]..sort();

    final first = _h('$seed|type') % 2 == 0 ? RangeReadType.also : RangeReadType.not;
    final order = [
      first,
      first == RangeReadType.also ? RangeReadType.not : RangeReadType.also,
    ];
    for (final type in order) {
      final correct = type == RangeReadType.also ? strongs : weaks;
      final wrong = type == RangeReadType.also ? weaks : strongs;
      if (correct.isEmpty || wrong.length < 2) continue;
      return _assemble(node, picked, type, correct, wrong, seed, dead);
    }
    return null;
  }

  static RangeReadQuestion _assemble(TreeNode node, AuthoredAction picked,
      RangeReadType type, List<String> correct, List<String> wrong, String seed,
      Set<String> dead) {
    final c = correct[_h('$seed|c') % correct.length];
    final w1i = _h('$seed|w1') % wrong.length;
    final rest = [...wrong]..removeAt(w1i);
    final w1 = wrong[w1i];
    final w2 = rest[_h('$seed|w2') % rest.length];
    final hands = [c, w1, w2]
      ..sort((a, b) => _h('$seed|o|$a').compareTo(_h('$seed|o|$b')));
    final used = <String>{};
    final options = <RangeReadOption>[];
    for (final h in hands) {
      var cards = comboFor(h, {...dead, ...deadKeys(used)}, '$seed|card|$h');
      if (cards.isEmpty) cards = comboFor(h, dead, '$seed|card|$h');
      used.addAll(cards);
      options.add(RangeReadOption(h, node.freqOf(picked, h), cards: cards));
    }
    return RangeReadQuestion(
      type: type,
      action: picked.wire,
      actionWord: wordFor(picked, node),
      options: options,
      correctIndex: hands.indexOf(c),
    );
  }

  // ── Which decision gets it ─────────────────────────────────────────────
  /// Decides whether to ask at this decision. [eligibleSeen] = eligible
  /// decisions of this hand BEFORE this one (that did not ask); [letterCount]
  /// = verdict letters of the hand so far INCLUDING this decision's.
  static RangeReadPlan plan({
    required String dayKey,
    required AuthoredTree tree,
    required TreeNode node,
    required AuthoredAction picked,
    required int eligibleSeen,
    required bool alreadyAsked,
    required bool handOver,
    required int letterCount,
  }) {
    if (alreadyAsked || letterCount >= maxLettersPerHand) {
      return const RangeReadPlan(null, false);
    }
    final q = build(
      tree: tree,
      node: node,
      picked: picked,
      seed: '$dayKey|${tree.id}|${node.id}',
    );
    if (q == null) return const RangeReadPlan(null, false);
    final target = _h('$dayKey|${tree.id}') % 2;
    return RangeReadPlan(q, eligibleSeen >= target || handOver);
  }
}
