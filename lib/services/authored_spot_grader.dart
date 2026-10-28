import '../models/authored_spot.dart';
import '../models/drill_models.dart';

/// Grades a hero decision in an AUTHORED spot against the solver's per-hand
/// action frequencies (frequency-only — the solver export carries no EV).
///
/// Pure. Emits the same [DrillGradeResult] the RNG drill grader does, so the
/// Daily Challenge pipeline (verdicts, streaks, coach, share, "Show range")
/// works unchanged.
///
/// Frequency bands (take-rate of the hero's hand class for the chosen action):
///   ≥ 0.65  → a pure / dominant line           → correct ("BEST")
///   ≥ 0.15  → a legitimate mixed line           → ok ("GOOD")
///   <  0.15 → the solver almost never does this → mistake ("LEAK")
/// A choice outside the spot's allowed options is always a mistake.
///
/// RANGE-STANDARD SOFTENING: a hand can disprefer an action that the OVERALL
/// range plays a lot (e.g. TT bets the J88 flop only 12%, but the range bets
/// 78%). Betting there is range-consistent, not a blunder — so a would-be LEAK
/// is softened to GOOD when the chosen action is a major part of the range
/// (share ≥ [_rangeStandardShare]). Only LEAK→GOOD is demoted; GOOD/BEST are
/// untouched, and an action the range ALSO avoids still reads LEAK.
class AuthoredSpotGrader {
  AuthoredSpotGrader._();

  static const double _pureThreshold = 0.65;
  static const double _mixThreshold = 0.15;

  /// If the whole range takes the chosen action at least this often, a
  /// hand-level LEAK is softened to GOOD (it's a standard line, just not this
  /// hand's preferred one).
  static const double _rangeStandardShare = 0.25;

  static DrillGrade _gradeFor(double freq) {
    if (freq >= _pureThreshold) return DrillGrade.correct;
    if (freq >= _mixThreshold) return DrillGrade.ok;
    return DrillGrade.mistake;
  }

  /// Range-wide share of [action] at this node: the summed frequency of every
  /// hand that takes [action], over the summed frequency across ALL actions.
  /// ~fraction of the range's combos that choose [action]. 0 when the node has
  /// no frequency data.
  static double _rangeShareOf(AuthoredDecision decision, AuthoredAction action) {
    var total = 0.0;
    var forAction = 0.0;
    for (final entry in decision.freq.entries) {
      for (final f in entry.value.values) {
        total += f;
        if (entry.key == action) forAction += f;
      }
    }
    return total > 0 ? forAction / total : 0.0;
  }

  /// Grade [heroAction] on [decision] for [handClass]. [displayHand] (the
  /// real cards, e.g. '9♠ 9♥') replaces the class in the coaching text.
  ///
  /// [explanation] is the authored plain-English strategy narrative for this
  /// node (sheet column "Explanation"). When present it becomes the main coach
  /// teaching line, with the hand-specific frequency note appended after it.
  static DrillGradeResult grade(
    AuthoredDecision decision,
    String handClass,
    AuthoredAction heroAction, {
    String? displayHand,
    String explanation = '',
  }) {
    final freq = decision.freqOf(heroAction, handClass);
    final shown = displayHand ?? handClass;
    final rawGrade = _gradeFor(freq);
    final best = decision.best;
    final bestFreq = decision.freqOf(best, handClass);

    // Range-standard softening: a hand-level LEAK on an action the whole range
    // plays a lot is really a GOOD (standard line, just not this hand's pick) —
    // e.g. betting TT on a J88 flop the range bets 78%. FOLD is excluded: a lot
    // of the range folds at many nodes, but folding a specific hand that wants
    // to continue is a genuine leak regardless of the range's fold share.
    final rangeShare = _rangeShareOf(decision, heroAction);
    final rangeStandard = rangeShare >= _rangeStandardShare;
    final softened = rawGrade == DrillGrade.mistake &&
        rangeStandard &&
        heroAction != best &&
        heroAction != AuthoredAction.fold;
    final grade = softened ? DrillGrade.ok : rawGrade;

    final actionPct = (freq * 100).round();
    final bestPct = (bestFreq * 100).round();
    final sharePct = (rangeShare * 100).round();
    final preflop = decision.street == AuthoredStreet.preflop;
    // Bet vs raise: putting chips in with NOTHING to call is a BET; doing it
    // over a villain's bet (toCall > 0) is a RAISE. Preflop, opening over the
    // blinds is conventionally a "raise" regardless. So a postflop raise action
    // reads as "bet" when first-in / into a check, and "raise" only when facing
    // a bet.
    final facingBet = decision.toCallBB > 0;
    final aggroIsRaise = preflop || facingBet;
    final bestLabel = _label(best, aggroIsRaise);
    final heroLabel = _label(heroAction, aggroIsRaise);
    final heroNoun = _noun(heroAction, aggroIsRaise); // 'bet'/'raise'/'check' …
    final bestNoun = _noun(best, aggroIsRaise);

    // The teaching line: name the solver's dominant play and how often the
    // hero's hand takes it. Honest and specific to this hand.
    final String reason;
    if (softened) {
      // Acknowledge the nuance: the action is range-standard, this hand is the
      // exception that prefers the other line.
      reason = 'The $heroNoun is standard here — the range takes it $sharePct% '
          'of the time. But $shown specifically prefers to $bestNoun '
          '($bestPct%), so you give up a little by choosing the $heroNoun '
          'instead.';
    } else {
      switch (grade) {
        case DrillGrade.correct:
          reason = 'The solver $heroLabel here $actionPct% of the time with '
              '$shown — a clear, dominant line.';
          break;
        case DrillGrade.ok:
          // When the hero picked the solver's TOP action, it's simply a valid
          // play — affirm it, don't hedge (you did what the solver does most).
          // Only contrast with `best` when the hero actually chose differently.
          reason = heroAction == best
              ? 'A valid play — the $heroNoun is the solver\'s most frequent '
                  'choice with $shown ($actionPct%). It mixes other lines too, '
                  'so this is a close spot.'
              : 'A fine mix: the solver $heroLabel $actionPct% with $shown, '
                  'but $bestLabel is the bigger share ($bestPct%).';
          break;
        case DrillGrade.mistake:
          reason = heroAction == best
              ? 'The solver rarely $heroLabel here with $shown ($actionPct%).'
              : 'The solver almost never $heroLabel here with $shown '
                  '($actionPct%) — it $bestLabel $bestPct% instead.';
          break;
      }
    }

    final verdictLead = switch (grade) {
      DrillGrade.correct => 'Best. ',
      DrillGrade.ok => 'Good. ',
      DrillGrade.mistake => 'Leak. ',
    };

    // With an authored explanation (the sheet's "WHAT HAPPENED / WHY / KEY
    // IDEA" verbal reasoning), that IS the coaching line — used verbatim, no
    // generic frequency note appended (it already explains the hand-specific
    // why, so a "Your X takes Y most often" tack-on just repeats it). The
    // persona still prepends a short in-character lead. Without an explanation,
    // fall back to the computed frequency reason. EXCEPTION: on a LEAK, append
    // the short hand-specific correction so the player hears what their exact
    // hand wanted (the authored text is written for the SOLVER line, which the
    // player didn't take).
    final note = explanation.trim();
    final String teaching;
    if (note.isEmpty) {
      teaching = reason;
    } else if (grade == DrillGrade.mistake && heroAction != best) {
      teaching =
          '$note\n\n${_handNote(grade, heroAction, best, shown, actionPct, bestPct, heroNoun, bestNoun)}';
    } else {
      teaching = note;
    }

    return DrillGradeResult(
      grade: grade,
      heroAction: heroAction.wire,
      recommendedAction: best.wire,
      recommendedWordRaw: bestNoun, // street-aware 'bet'/'raise'/… for {action}
      explanation: '$verdictLead$teaching',
      headlineReason: teaching,
      handTopPercent: 0, // not meaningful for an authored fixed hand
      gtoAction: best.wire,
      gtoRangePercent: bestFreq * 100,
      gtoReason: teaching,
      exploitAction: best.wire,
      exploitRangePercent: bestFreq * 100,
      exploitReason: teaching,
      trace: [
        'AUTHORED spot grade',
        'hand=$handClass action=${heroAction.wire} freq=$freq',
        'best=${best.wire} bestFreq=$bestFreq',
        'verdict=${grade.name}',
      ],
    );
  }

  /// One short sentence tying the range narrative to the hero's SPECIFIC hand
  /// and chosen action — appended after the authored explanation.
  static String _handNote(
    DrillGrade grade,
    AuthoredAction hero,
    AuthoredAction best,
    String shown,
    int actionPct,
    int bestPct,
    String heroNoun,
    String bestNoun,
  ) {
    switch (grade) {
      case DrillGrade.correct:
        return 'Your $shown is right in it — it takes the $heroNoun $actionPct% '
            'of the time.';
      case DrillGrade.ok:
        return hero == best
            ? 'Your $shown takes the $heroNoun most often ($actionPct%) — a '
                'valid play; it just mixes in other lines too.'
            : 'Your $shown mostly prefers to $bestNoun ($bestPct%), but the '
                '$heroNoun is a reasonable mix.';
      case DrillGrade.mistake:
        return 'But your $shown specifically wants to $bestNoun ($bestPct%) — '
            'the $heroNoun loses value with this exact hand.';
    }
  }

  /// Verb form ('raises'/'bets'). The aggressive action is 'raises' only when
  /// [aggroIsRaise] (preflop open, or there's a bet to raise over); otherwise
  /// putting chips in is a 'bets'.
  static String _label(AuthoredAction a, bool aggroIsRaise) => switch (a) {
        AuthoredAction.fold => 'folds',
        AuthoredAction.check => 'checks',
        AuthoredAction.call => 'calls',
        AuthoredAction.raise => aggroIsRaise ? 'raises' : 'bets',
        AuthoredAction.allin => 'jams',
      };

  /// Noun/base form of an action ('the raise'/'the bet', 'the check'). Same
  /// bet-vs-raise rule as [_label].
  static String _noun(AuthoredAction a, bool aggroIsRaise) => switch (a) {
        AuthoredAction.fold => 'fold',
        AuthoredAction.check => 'check',
        AuthoredAction.call => 'call',
        AuthoredAction.raise => aggroIsRaise ? 'raise' : 'bet',
        AuthoredAction.allin => 'jam',
      };
}
