/// AUTHORED TREE — a navigable, solver-backed game tree for the Daily
/// Challenge, sourced from a solver export. Unlike a scripted line, the hero can
/// pick any legal action at each node and the villain (BTN) responds
/// deterministically from the solver data, so the hand branches.
///
/// Pure + Firestore-serializable (no Flutter). The tree lives in Firestore
/// (`authored_spots/{id}`), read-only to clients, authored out of band.
///
/// Card/handclass format matches the rest of the app: cards are glyphs
/// ('A♠', '10♦'), hand classes are the 169 keys ('99', 'AKo').
library;

import 'authored_spot.dart' show AuthoredAction, AuthoredActionX;

export 'authored_spot.dart' show AuthoredAction, AuthoredActionX;

/// Street of a node.
enum TreeStreet { preflop, flop, turn, river }

/// Who acts at a node.
enum TreeActor { hero, villain }

/// One node in the game tree.
class TreeNode {
  /// Unique id within the tree (e.g. 'n3', or a path-derived key).
  final String id;

  final TreeStreet street;

  /// Board visible at this node (glyph format). `[]` preflop.
  final List<String> board;

  final TreeActor actor;

  /// Pot / to-call in BB at this node (for the UI chip + sizing label).
  final double potBB;
  final double toCallBB;

  /// Short label of what the acting player faces (e.g. 'BTN bets 51% pot').
  final String prompt;

  /// Plain-English strategy narrative for THIS node, authored alongside the
  /// solver export (sheet column "Explanation"). Present on hero decision
  /// nodes; '' when not authored. Used verbatim as the coach's after-action
  /// teaching line (see AuthoredSpotGrader).
  final String explanation;

  /// The actions available here, in display order.
  final List<AuthoredAction> actions;

  /// Per-action total-to-amount sizing in BB (for raise/bet/all-in chips).
  final Map<AuthoredAction, double> sizingBB;

  /// Per-ACTION per-HAND frequency: action → (handClass → freq 0..1).
  final Map<AuthoredAction, Map<String, double>> freq;

  /// Child node id reached by taking a given action (null = terminal).
  /// e.g. {raise: 'n7', call: 'n8', fold: null}.
  final Map<AuthoredAction, String?> children;

  const TreeNode({
    required this.id,
    required this.street,
    required this.board,
    required this.actor,
    required this.potBB,
    required this.toCallBB,
    required this.prompt,
    required this.actions,
    required this.sizingBB,
    required this.freq,
    required this.children,
    this.explanation = '',
  });

  bool get isHero => actor == TreeActor.hero;

  /// Solver frequency the [handClass] takes [action] here (0 if absent).
  double freqOf(AuthoredAction action, String handClass) =>
      freq[action]?[handClass] ?? 0.0;

  /// Whether [handClass] has ANY solver frequency at this node. The solver
  /// only lists hands that can REACH a node; if the hero hand appears in none
  /// of the actions' frequency maps, the node is unreachable for this hand —
  /// presenting it as a decision would misgrade (every action reads as 0% →
  /// LEAK, and the "best" degenerates to the first action). The walker uses
  /// this to end the hand instead of asking an impossible decision.
  bool hasHeroFreq(String handClass) =>
      freq.values.any((m) => m.containsKey(handClass));

  /// The action with the highest frequency FOR THE WHOLE RANGE at this node —
  /// used to pick the villain's deterministic line. Weighted by combos is
  /// overkill; the simple range-wide argmax of summed frequency is stable and
  /// matches "most-likely action".
  AuthoredAction dominantRangeAction() {
    var best = actions.first;
    var bestSum = -1.0;
    for (final a in actions) {
      final grid = freq[a];
      if (grid == null) continue;
      var sum = 0.0;
      for (final v in grid.values) {
        sum += v;
      }
      if (sum > bestSum) {
        bestSum = sum;
        best = a;
      }
    }
    return best;
  }

  factory TreeNode.fromJson(Map<String, dynamic> j) {
    AuthoredAction act(String s) => AuthoredAction.values
        .firstWhere((a) => a.wire == s, orElse: () => AuthoredAction.fold);
    Map<AuthoredAction, Map<String, double>> parseFreq(dynamic raw) {
      final out = <AuthoredAction, Map<String, double>>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) {
            out[act(k.toString())] = {
              for (final e in v.entries)
                e.key.toString(): (e.value as num).toDouble(),
            };
          }
        });
      }
      return out;
    }

    return TreeNode(
      id: j['id'].toString(),
      street: TreeStreet.values.byName(j['street'] as String),
      board: (j['board'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      actor: TreeActor.values.byName(j['actor'] as String),
      potBB: (j['potBB'] as num?)?.toDouble() ?? 0,
      toCallBB: (j['toCallBB'] as num?)?.toDouble() ?? 0,
      prompt: j['prompt']?.toString() ?? '',
      explanation: j['explanation']?.toString() ?? '',
      actions: (j['actions'] as List?)
              ?.map((e) => act(e.toString()))
              .toList() ??
          const [],
      sizingBB: {
        for (final e in (j['sizingBB'] as Map? ?? {}).entries)
          act(e.key.toString()): (e.value as num).toDouble(),
      },
      freq: parseFreq(j['freq']),
      children: {
        for (final e in (j['children'] as Map? ?? {}).entries)
          act(e.key.toString()): e.value?.toString(),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'street': street.name,
        'board': board,
        'actor': actor.name,
        'potBB': potBB,
        'toCallBB': toCallBB,
        'prompt': prompt,
        if (explanation.isNotEmpty) 'explanation': explanation,
        'actions': [for (final a in actions) a.wire],
        'sizingBB': {for (final e in sizingBB.entries) e.key.wire: e.value},
        'freq': {
          for (final e in freq.entries) e.key.wire: e.value,
        },
        'children': {for (final e in children.entries) e.key.wire: e.value},
      };
}

/// A full authored spot as a game tree with a fixed hero hand.
class AuthoredTree {
  final String id;
  final String title;
  final String formatLabel;
  final double stackBB;
  final bool anteMode;

  final String heroPosition; // 'LJ'
  final String villainPosition; // 'BTN'
  final List<String> heroCards; // glyph, e.g. ['9♠','9♥']
  final String heroHandClass; // '99'

  /// All nodes, keyed by id.
  final Map<String, TreeNode> nodes;

  /// The id of the first node the hero acts on (entry point).
  final String rootId;

  const AuthoredTree({
    required this.id,
    required this.title,
    required this.formatLabel,
    required this.stackBB,
    required this.anteMode,
    required this.heroPosition,
    required this.villainPosition,
    required this.heroCards,
    required this.heroHandClass,
    required this.nodes,
    required this.rootId,
  });

  TreeNode? node(String? id) => id == null ? null : nodes[id];
  TreeNode get root => nodes[rootId]!;

  factory AuthoredTree.fromJson(Map<String, dynamic> j) => AuthoredTree(
        id: j['id'].toString(),
        title: j['title']?.toString() ?? '',
        formatLabel: j['formatLabel']?.toString() ?? '',
        stackBB: (j['stackBB'] as num?)?.toDouble() ?? 0,
        anteMode: j['anteMode'] == true,
        heroPosition: j['heroPosition']?.toString() ?? '',
        villainPosition: j['villainPosition']?.toString() ?? '',
        heroCards:
            (j['heroCards'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        heroHandClass: j['heroHandClass']?.toString() ?? '',
        rootId: j['rootId'].toString(),
        nodes: {
          for (final e in (j['nodes'] as Map? ?? {}).entries)
            e.key.toString():
                TreeNode.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'formatLabel': formatLabel,
        'stackBB': stackBB,
        'anteMode': anteMode,
        'heroPosition': heroPosition,
        'villainPosition': villainPosition,
        'heroCards': heroCards,
        'heroHandClass': heroHandClass,
        'rootId': rootId,
        'nodes': {for (final e in nodes.entries) e.key: e.value.toJson()},
      };
}
