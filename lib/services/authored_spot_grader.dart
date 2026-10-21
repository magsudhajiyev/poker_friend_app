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
class AuthoredSpotGrader {
  AuthoredSpotGrader._();

  static const double _pureThreshold = 0.65;
  static const double _mixThreshold = 0.15;

  static DrillGrade _gradeFor(double freq) {
    if (freq >= _pureThreshold) return DrillGrade.correct;
    if (freq >= _mixThreshold) return DrillGrade.ok;
    return DrillGrade.mistake;
  }

  /// Grade [heroAction] on [decision] for [handClass]. [displayHand] (the
  /// real cards, e.g. '9♠ 9♥') replaces the class in the coaching text.
  static DrillGradeResult grade(
    AuthoredDecision decision,
    String handClass,
    AuthoredAction heroAction, {
    String? displayHand,
  }) {
    final freq = decision.freqOf(heroAction, handClass);
    final shown = displayHand ?? handClass;
    final grade = _gradeFor(freq);
    final best = decision.best;
    final bestFreq = decision.freqOf(best, handClass);

    final actionPct = (freq * 100).round();
    final bestPct = (bestFreq * 100).round();
    final bestLabel = _label(best);
    final heroLabel = _label(heroAction);

    // The teaching line: name the solver's dominant play and how often the
    // hero's hand takes it. Honest and specific to this hand.
    final String reason;
    switch (grade) {
      case DrillGrade.correct:
        reason = 'The solver $heroLabel here $actionPct% of the time with '
            '$shown — a clear, dominant line.';
        break;
      case DrillGrade.ok:
        reason = 'A fine mix: the solver $heroLabel $actionPct% with $shown, '
            'but $bestLabel is the bigger share ($bestPct%).';
        break;
      case DrillGrade.mistake:
        reason = heroAction == best
            ? 'The solver rarely $heroLabel here with $shown ($actionPct%).'
            : 'The solver almost never $heroLabel here with $shown '
                '($actionPct%) — it $bestLabel $bestPct% instead.';
        break;
    }

    final verdictLead = switch (grade) {
      DrillGrade.correct => 'Best. ',
      DrillGrade.ok => 'Good. ',
      DrillGrade.mistake => 'Leak. ',
    };

    return DrillGradeResult(
      grade: grade,
      heroAction: heroAction.wire,
      recommendedAction: best.wire,
      explanation: '$verdictLead$reason',
      headlineReason: reason,
      handTopPercent: 0, // not meaningful for an authored fixed hand
      gtoAction: best.wire,
      gtoRangePercent: bestFreq * 100,
      gtoReason: reason,
      exploitAction: best.wire,
      exploitRangePercent: bestFreq * 100,
      exploitReason: reason,
      trace: [
        'AUTHORED spot grade',
        'hand=$handClass action=${heroAction.wire} freq=$freq',
        'best=${best.wire} bestFreq=$bestFreq',
        'verdict=${grade.name}',
      ],
    );
  }

  static String _label(AuthoredAction a) => switch (a) {
        AuthoredAction.fold => 'folds',
        AuthoredAction.check => 'checks',
        AuthoredAction.call => 'calls',
        AuthoredAction.raise => 'raises',
        AuthoredAction.allin => 'jams',
      };
}
