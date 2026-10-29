import '../models/authored_spot.dart' show AuthoredDecision, AuthoredStreet;
import '../models/authored_tree.dart';
import '../models/drill_models.dart';
import 'authored_spot_grader.dart';

/// Walks an [AuthoredTree] for a fixed hero hand: the hero picks actions at
/// hero nodes (graded against the solver), the villain auto-advances by its
/// most-likely action, and the walk stops at a terminal node (a fold, or the
/// tree running out of children).
///
/// Pure + deterministic. The UI drives it: it reads [current] to render, calls
/// [applyHeroAction] when the hero picks, and [advanceVillains] to auto-play
/// villain nodes until the next hero decision (or the hand ends).
class AuthoredTreeWalker {
  final AuthoredTree tree;
  String? _currentId;

  /// Villain actions auto-played since the last hero decision — so the UI can
  /// show the chips the hero is now facing (e.g. 'BTN bets 51%').
  final List<VillainMove> lastVillainMoves = [];

  AuthoredTreeWalker(this.tree) : _currentId = tree.rootId;

  /// The node awaiting action (hero or villain), or null when the hand ended.
  TreeNode? get current => tree.node(_currentId);

  bool get isHeroTurn => current?.isHero ?? false;
  bool get isOver => current == null;

  String get heroHand => tree.heroHandClass;

  /// When the hero's chosen action had no solved continuation, the hand was
  /// kept alive by rerouting through THIS solver-line action (null = the
  /// chosen action's own branch was followed, or the hand truly ended).
  AuthoredAction? lastReroute;

  /// Grade + apply the hero's [action] at the current (hero) node, then
  /// auto-advance through any villain nodes to the next hero decision (or the
  /// end). Returns the grade of the hero's move.
  ///
  /// Actions WITHOUT a solved continuation (synthetic test options like a
  /// "Bet" where the solver only checks, or side-lines the export didn't walk, like
  /// the 4-bet) are graded honestly against their frequency — and then the
  /// hand CONTINUES along the solver's main branch (the hero-hand-dominant
  /// action that has a child), so every run reaches a real terminal. FOLD is
  /// the exception: folding genuinely ends the hand.
  DrillGradeResult applyHeroAction(AuthoredAction action) {
    final node = current;
    if (node == null || !node.isHero) {
      throw StateError('applyHeroAction called when not a hero turn');
    }
    final grade = AuthoredSpotGrader.grade(
      _asDecision(node),
      heroHand,
      action,
      displayHand:
          tree.heroCards.isEmpty ? null : tree.heroCards.join(' '),
      explanation: node.explanation,
    );
    lastReroute = null;
    String? next = node.children[action];
    if (next == null && action != AuthoredAction.fold) {
      AuthoredAction? dom;
      var bestF = -1.0;
      for (final a in node.actions) {
        if (node.children[a] == null) continue;
        final f = node.freqOf(a, heroHand);
        if (f > bestF) {
          bestF = f;
          dom = a;
        }
      }
      if (dom != null) {
        next = node.children[dom];
        lastReroute = dom;
      }
    }
    _currentId = next;
    advanceVillains();
    return grade;
  }

  /// Auto-play villain nodes (deterministic most-likely action) until the
  /// next hero decision or the hand ends. Records each villain move.
  ///
  /// The villain's choice is its highest-frequency action AMONG the branches
  /// the solver actually walked (those with a child node). Without that
  /// restriction the range-wide argmax at response nodes is often FOLD (most
  /// hands fold to aggression), which would instantly end every hand — the
  /// deterministic line must follow the solved tree. When NO action has a
  /// child (a pure terminal response like fold/call closing the hand), the
  /// plain range argmax decides the closing move.
  void advanceVillains() {
    lastVillainMoves.clear();
    var guard = 0;
    while (current != null && !current!.isHero && guard++ < 20) {
      final node = current!;
      final withChildren =
          node.actions.where((a) => node.children[a] != null).toList();
      final action = withChildren.isEmpty
          ? node.dominantRangeAction()
          : _argmaxRange(node, withChildren);
      lastVillainMoves.add(VillainMove(
        action: action,
        sizeBB: node.sizingBB[action] ?? 0,
        street: node.street,
        board: node.board,
      ));
      _currentId = node.children[action];
    }
    // Guard tripped on a villain node (malformed/cyclic tree): end the hand
    // instead of leaving the UI waiting on a node nobody acts on.
    if (current != null && !current!.isHero) _currentId = null;
    // If we landed on a hero decision the hero hand can never reach (the
    // solver lists no frequency for it here), end the hand rather than ask an
    // impossible decision that would always misgrade as a LEAK. This happens
    // on deep reroute lines where the hand took an earlier action at ~0%.
    final here = current;
    if (here != null && here.isHero && !here.hasHeroFreq(heroHand)) {
      _currentId = null;
    }
  }

  static AuthoredAction _argmaxRange(
      TreeNode node, List<AuthoredAction> candidates) {
    var best = candidates.first;
    var bestSum = -1.0;
    for (final a in candidates) {
      var sum = 0.0;
      for (final v in (node.freq[a] ?? const <String, double>{}).values) {
        sum += v;
      }
      if (sum > bestSum) {
        bestSum = sum;
        best = a;
      }
    }
    return best;
  }

  /// Adapt a tree node into the [AuthoredDecision] shape the existing
  /// frequency grader already understands (so grading logic is shared).
  AuthoredDecision _asDecision(TreeNode node) => AuthoredDecision(
        street: switch (node.street) {
          TreeStreet.preflop => AuthoredStreet.preflop,
          TreeStreet.flop => AuthoredStreet.flop,
          TreeStreet.turn => AuthoredStreet.turn,
          TreeStreet.river => AuthoredStreet.river,
        },
        board: node.board,
        prompt: node.prompt,
        options: node.actions,
        best: node.dominantHeroAction(heroHand),
        potBB: node.potBB,
        toCallBB: node.toCallBB,
        freq: node.freq,
      );
}

/// A villain action auto-played by the walker (shown as a chip to the hero).
class VillainMove {
  final AuthoredAction action;
  final double sizeBB;
  final TreeStreet street;
  final List<String> board;
  const VillainMove({
    required this.action,
    required this.sizeBB,
    required this.street,
    required this.board,
  });
}

extension on TreeNode {
  /// The hero's best action here = the one the hero's hand takes most often.
  AuthoredAction dominantHeroAction(String handClass) {
    var best = actions.first;
    var bestF = -1.0;
    for (final a in actions) {
      final f = freqOf(a, handClass);
      if (f > bestF) {
        bestF = f;
        best = a;
      }
    }
    return best;
  }
}

/// True when [action] is a trainer-only option the solver never lists at
/// [node] (today: the synthetic "Bet" added where the solver only checks).
bool isSyntheticAction(TreeNode node, AuthoredAction action) =>
    action == AuthoredAction.raise &&
    !node.actions.contains(AuthoredAction.raise) &&
    node.actions.contains(AuthoredAction.check);

/// Size (BB, 1 decimal) of the synthetic trainer Bet: 1/3 of the current pot,
/// minimum 1BB.
/// Null = do not offer it: the node already has a real raise, check is not
/// available, or the size reaches the all-in (it would be a second jam).
double? syntheticBetSizeBB(TreeNode node) {
  if (!isSyntheticAction(node, AuthoredAction.raise)) return null;
  final third = node.potBB / 3;
  final size = ((third < 1.0 ? 1.0 : third) * 10).round() / 10;
  final jam = node.sizingBB[AuthoredAction.allin];
  if (jam != null && size >= jam) return null;
  return size;
}
