/// AUTHORED SPOTS — fully-specified, deterministic hands for the Daily
/// Challenge, sourced from a real solver export instead of the RNG drill
/// engine. Each spot is a fixed hero hand playing a fixed betting line against a
/// board, with the solver's per-hand action frequencies baked in so the coach
/// can grade move-by-move.
///
/// This model is PURE (no Firestore, no Flutter). It sits ALONGSIDE the RNG
/// preflop path — it does not replace it. One solver export becomes an
/// [AuthoredSpotTemplate] (the board + line + per-decision solver grids); from
/// one template we mint several [AuthoredSpot]s, one per hero hand (99, TT, …),
/// so a single solved hand yields a bank of daily puzzles.
///
/// Card format matches the drill table: rank + unicode glyph, ten = '10'
/// (e.g. 'A♠', '10♦', '9♥'). Hand classes are the 169-grid keys ('99', 'AKo').
library;

/// One action the hero can choose at a decision node.
enum AuthoredAction { fold, check, call, raise, allin }

extension AuthoredActionX on AuthoredAction {
  /// Wire/engine string used by the grader and records
  /// ('fold'|'check'|'call'|'raise'|'allin').
  String get wire => switch (this) {
        AuthoredAction.fold => 'fold',
        AuthoredAction.check => 'check',
        AuthoredAction.call => 'call',
        AuthoredAction.raise => 'raise',
        AuthoredAction.allin => 'allin',
      };
}

/// The street a decision happens on.
enum AuthoredStreet { preflop, flop, turn, river }

/// A single hero decision inside an authored spot. Holds everything needed to
/// render it (prompt, available buttons, board so far) and to grade it (the
/// solver take-rate for EVERY action, keyed by hero hand class).
class AuthoredDecision {
  final AuthoredStreet street;

  /// Board visible at this decision (glyph format). `[]` preflop.
  final List<String> board;

  /// Short human label of what the hero faces, e.g.
  /// 'BTN 3-bets to 7.35bb' or 'BTN bets 51% pot'.
  final String prompt;

  /// The actions the hero may pick here (drives which buttons show).
  final List<AuthoredAction> options;

  /// The solver-best action (what earns "BEST").
  final AuthoredAction best;

  /// Pot / to-call in BB at this node (for the UI chip + sizing label).
  final double potBB;
  final double toCallBB;

  /// The size (total to-amount in BB) the hero commits for a raise, if any —
  /// mirrors the solver's chosen sizing so the table shows a real number.
  final double? raiseToBB;

  // ── Table chips/tags shown WHILE the hero is deciding ────────────────────
  /// What the hero already has committed in front of their seat at this node
  /// (e.g. their 2.1bb open preflop). 0 = no chip.
  final double heroChipBB;

  /// A short action tag on the hero seat at this node (e.g. 'Check' on the
  /// flop after they checked to the c-bet). Empty = no tag.
  final String heroTag;

  /// What the villain has bet into this node — the chip in front of the
  /// villain that the hero is facing (e.g. the 7.35bb 3-bet, or the 8bb
  /// c-bet). 0 = no villain chip. This replaces the floating prompt text.
  final double villainBetBB;

  /// Short label for the villain's bet (e.g. '3-bet', 'Bet 51%').
  final String villainTag;

  /// Per-ACTION per-HAND take-rate: action → (handClass → frequency 0..1).
  /// The grader looks up the hero's hand class in each action's map; the sum
  /// across actions for a given hand is ~1. Missing hand/action ⇒ 0 freq.
  final Map<AuthoredAction, Map<String, double>> freq;

  /// The hero's FULL range entering this decision (hand → weight) — the
  /// "before action" range from the solver. Lets the range view show every
  /// hand that reached this node, not just the ones taking the exported
  /// action, so hands with no exported split still appear (as "rest of
  /// range"). Optional — omit preflop where [freq] already covers all actions.
  final Map<String, double>? rangeContext;

  const AuthoredDecision({
    required this.street,
    required this.board,
    required this.prompt,
    required this.options,
    required this.best,
    required this.potBB,
    required this.toCallBB,
    this.raiseToBB,
    required this.freq,
    this.rangeContext,
    this.heroChipBB = 0,
    this.heroTag = '',
    this.villainBetBB = 0,
    this.villainTag = '',
  });

  /// Solver frequency the hero's [handClass] takes [action] (0 if absent).
  double freqOf(AuthoredAction action, String handClass) =>
      freq[action]?[handClass] ?? 0.0;
}

/// A playable authored spot: one hero hand walking one solved line.
class AuthoredSpot {
  /// Stable id, e.g. 'lj-btn-ts9c4d-99'.
  final String id;

  /// Human title for logs/share, e.g. 'MTT 70bb · LJ vs BTN · T94 two-tone'.
  final String title;

  final String formatLabel; // 'MTT · 70bb · 9-max'
  final double stackBB;
  final bool anteMode;

  final String heroPosition; // full name, e.g. 'LJ'
  final List<String> heroCards; // glyph format, e.g. ['9♠','9♥']
  final String heroHandClass; // 169 key, e.g. '99'

  /// The villain summary shown at the table ('BTN' plus a short note).
  final String villainPosition; // 'BTN'

  /// The ordered hero decisions (preflop → flop → …).
  final List<AuthoredDecision> decisions;

  const AuthoredSpot({
    required this.id,
    required this.title,
    required this.formatLabel,
    required this.stackBB,
    required this.anteMode,
    required this.heroPosition,
    required this.heroCards,
    required this.heroHandClass,
    required this.villainPosition,
    required this.decisions,
  });
}
