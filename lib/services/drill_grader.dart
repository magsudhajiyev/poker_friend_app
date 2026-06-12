import '../models/drill_models.dart';
import 'drill_hand_strength.dart';

/// Grades hero decisions in training drills against simple, explainable
/// exploit heuristics.
///
/// Ranges are expressed as "top X% of combos" cutoffs (via
/// DrillHandStrength). A small set of deterministic rules shifts those
/// cutoffs based on the measured tendencies of the opponents in the pot, and
/// every fired rule contributes a human-readable note that names the player
/// and the stat — that explanation IS the product.
class DrillGrader {
  DrillGrader._();

  /// Hands within this many percentage points of a range boundary grade as
  /// "ok" instead of "mistake" — close spots shouldn't punish either choice.
  static const double _closeBand = 4.0;

  static const Map<String, double> _openThreshold = {
    'EP': 14,
    'MP': 18,
    'CO': 26,
    'BTN': 42,
    'SB': 35,
    'BB': 100, // BB never opens — checks its option
  };

  static DrillGradeResult grade(DrillDecisionContext ctx, String heroAction,
      {double? raiseToBB}) {
    switch (ctx.scenario) {
      case DrillScenario.unopened:
        return _gradeUnopened(ctx, heroAction, raiseToBB);
      case DrillScenario.vsLimpers:
        return _gradeVsLimpers(ctx, heroAction, raiseToBB);
      case DrillScenario.vsRaise:
        return _gradeVsRaise(ctx, heroAction, raiseToBB);
      case DrillScenario.vs3betAsAggressor:
        return _gradeVs3betAsAggressor(ctx, heroAction);
      case DrillScenario.vs3betCold:
        return _gradeVs3betCold(ctx, heroAction);
    }
  }

  // ── Unopened pot ────────────────────────────────────────────────────

  static DrillGradeResult _gradeUnopened(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final notes = <String>[];
    double openThresh = _openThreshold[ctx.positionGroup] ?? 20;

    final aggro3bettor = _strongest(ctx.playersBehind,
        (p) => p.threeBet >= 10 && !p.isGenericBot, (p) => p.threeBet);
    if (aggro3bettor != null) {
      openThresh -= 4;
      notes.add(
          '${aggro3bettor.name} 3-bets ${_pct(aggro3bettor.threeBet)} behind you '
          '(${aggro3bettor.confidenceLabel}) — tighten your opens and be ready to play back.');
    }

    final stationBehind = _strongest(ctx.playersBehind,
        (p) => p.vpip >= 40 && p.pfr < 15 && !p.isGenericBot, (p) => p.vpip);
    if (stationBehind != null) {
      openThresh -= 2;
      notes.add('${stationBehind.name} plays ${_pct(stationBehind.vpip)} of '
          'hands and rarely folds preflop — open hands that flop well, skip thin steals.');
    }
    openThresh = openThresh.clamp(8.0, 60.0).toDouble();

    final inRange = DrillHandStrength.inTopPercent(ctx.handClass, openThresh);
    final recommended = inRange ? 'raise' : 'fold';
    final baseReason = inRange
        ? '${ctx.handClass} is inside the top ${_pct(openThresh)} you should open from ${_posName(ctx.positionGroup)}.'
        : '${ctx.handClass} is outside a ${_posName(ctx.positionGroup)} opening range (top ${_pct(openThresh)}).';

    var result = _compare(
      ctx: ctx,
      action: action,
      recommended: recommended,
      boundary: openThresh,
      baseReason: baseReason,
      notes: notes,
    );
    return _withSizingNote(result, action, raiseToBB,
        idealTo: 2.5, label: 'open', stackBB: ctx.stackBB);
  }

  // ── Limped pot ──────────────────────────────────────────────────────

  static DrillGradeResult _gradeVsLimpers(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final notes = <String>[];
    final limperCount = ctx.limpers.length;
    double isoThresh =
        (_openThreshold[ctx.positionGroup] ?? 20) + 4 + 2.0 * limperCount;
    if (ctx.positionGroup == 'BB') isoThresh = 16 + 2.0 * limperCount;

    final loosePassive = _strongest(ctx.limpers,
        (p) => p.vpip >= 38 && p.pfr <= 15 && !p.isGenericBot, (p) => p.vpip);
    if (loosePassive != null) {
      isoThresh += 4;
      notes.add('${loosePassive.name} limps into most pots '
          '(VPIP ${_pct(loosePassive.vpip)}, ${loosePassive.confidenceLabel}) — '
          'isolate him wide and take the betting lead.');
    }
    isoThresh = isoThresh.clamp(10.0, 65.0).toDouble();

    final overlimpCeiling = isoThresh + 12;
    final inIso = DrillHandStrength.inTopPercent(ctx.handClass, isoThresh);
    final canCheck = ctx.toCallBB <= 0;

    final String recommended;
    if (inIso) {
      recommended = 'raise';
    } else if (canCheck) {
      recommended = 'check';
    } else if (DrillHandStrength.inTopPercent(
        ctx.handClass, overlimpCeiling)) {
      recommended = 'call';
    } else {
      recommended = 'fold';
    }

    final baseReason = inIso
        ? 'With $limperCount limper${limperCount > 1 ? 's' : ''} in, ${ctx.handClass} is a clear isolation raise — punish the dead money.'
        : canCheck
            ? 'Take the free flop — ${ctx.handClass} isn\'t strong enough to bloat a limped pot.'
            : DrillHandStrength.inTopPercent(ctx.handClass, overlimpCeiling)
                ? '${ctx.handClass} plays fine as an overlimp, but isn\'t strong enough to iso-raise.'
                : '${ctx.handClass} isn\'t worth a big blind even in a limped pot.';

    var result = _compare(
      ctx: ctx,
      action: action,
      recommended: recommended,
      boundary: isoThresh,
      baseReason: baseReason,
      notes: notes,
    );
    return _withSizingNote(result, action, raiseToBB,
        idealTo: 3.0 + limperCount, label: 'iso-raise', stackBB: ctx.stackBB);
  }

  // ── Facing a single raise ───────────────────────────────────────────

  static DrillGradeResult _gradeVsRaise(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final notes = <String>[];
    final opener = ctx.opener;
    double threeBetThresh = 5;
    double callThresh = switch (ctx.positionGroup) {
      'BB' => 28,
      'SB' => 10,
      _ => 14,
    };

    if (opener != null && !opener.isGenericBot) {
      if (opener.fold3bet >= 60) {
        threeBetThresh += 6;
        notes.add('${opener.name} folds to 3-bets ${_pct(opener.fold3bet)} '
            '(${opener.confidenceLabel}) — 3-bet him relentlessly.');
      }
      if (opener.vpip >= 33) {
        threeBetThresh += 4;
        callThresh += 4;
        notes.add('${opener.name} opens loose (VPIP ${_pct(opener.vpip)}) — '
            'widen your value 3-bets and calls against him.');
      } else if (opener.vpip <= 17) {
        threeBetThresh -= 2;
        callThresh -= 5;
        notes.add('${opener.name} plays only ${_pct(opener.vpip)} of hands — '
            'his raises are premium-heavy, give them respect.');
      }
      if (opener.archetype == 'Maniac' || opener.pfr >= 28) {
        threeBetThresh += 5;
        callThresh += 5;
        notes.add('${opener.name} raises ${_pct(opener.pfr)} of hands — '
            'his range is wide, so play back with hands you\'d normally fold.');
      }
    }

    final shortStacked = ctx.stackBB <= 25;
    if (shortStacked) {
      threeBetThresh += 2;
      callThresh = ctx.positionGroup == 'BB' ? 18 : 6;
      notes.add('At ${ctx.stackBB.toStringAsFixed(0)}BB this is '
          '3-bet-jam-or-fold territory — flatting burns your stack.');
    }
    threeBetThresh = threeBetThresh.clamp(2.0, 30.0).toDouble();
    callThresh =
        callThresh.clamp(threeBetThresh, 45.0).toDouble();

    final top = DrillHandStrength.topPercent(ctx.handClass);
    final String recommended;
    if (top <= threeBetThresh) {
      recommended = 'raise';
    } else if (top <= callThresh) {
      recommended = 'call';
    } else {
      recommended = 'fold';
    }

    final baseReason = switch (recommended) {
      'raise' =>
        '${ctx.handClass} is in your 3-bet range here (top ${_pct(threeBetThresh)}).',
      'call' =>
        '${ctx.handClass} is strong enough to continue but not to re-raise — flat and play a pot in position when you can.',
      _ =>
        '${ctx.handClass} doesn\'t make the cut against a raise (continue with roughly the top ${_pct(callThresh)}).',
    };

    final boundary =
        recommended == 'raise' ? threeBetThresh : callThresh;
    var result = _compare(
      ctx: ctx,
      action: action,
      recommended: recommended,
      boundary: boundary,
      baseReason: baseReason,
      notes: notes,
      secondaryBoundary:
          recommended == 'fold' ? threeBetThresh : null,
    );
    return _withSizingNote(result, action, raiseToBB,
        idealTo: ctx.currentBetBB * 3, label: '3-bet', stackBB: ctx.stackBB);
  }

  // ── Hero opened, now facing a re-raise ──────────────────────────────

  static DrillGradeResult _gradeVs3betAsAggressor(
      DrillDecisionContext ctx, String action) {
    final notes = <String>[];
    final threeBettor = ctx.opener;
    double fourBetThresh = 2.5;
    double continueThresh = 9;

    if (threeBettor != null && !threeBettor.isGenericBot) {
      if (threeBettor.threeBet >= 9) {
        fourBetThresh += 1.5;
        continueThresh += 5;
        notes.add('${threeBettor.name} 3-bets ${_pct(threeBettor.threeBet)} '
            '(${threeBettor.confidenceLabel}) — too wide to give him your good hands, continue lighter.');
      } else if (threeBettor.threeBet <= 4.5) {
        continueThresh -= 3;
        notes.add('${threeBettor.name} almost never 3-bets '
            '(${_pct(threeBettor.threeBet)}) — this re-raise is the top of the deck, fold everything but premiums.');
      }
    }
    if (ctx.stackBB <= 25) {
      notes.add('Short-stacked: continuing means getting it in — '
          'jam or fold, never flat.');
    }
    fourBetThresh = fourBetThresh.clamp(1.0, 10.0).toDouble();
    continueThresh =
        continueThresh.clamp(fourBetThresh, 25.0).toDouble();

    final top = DrillHandStrength.topPercent(ctx.handClass);
    final String recommended;
    if (top <= fourBetThresh) {
      recommended = 'raise';
    } else if (top <= continueThresh) {
      recommended = 'call';
    } else {
      recommended = 'fold';
    }

    final baseReason = switch (recommended) {
      'raise' => '${ctx.handClass} is a premium — 4-bet for value.',
      'call' =>
        '${ctx.handClass} is strong enough to see a flop against the 3-bet.',
      _ =>
        'Opening ${ctx.handClass} was fine, but it can\'t continue against a 3-bet — let it go.',
    };

    return _compare(
      ctx: ctx,
      action: action,
      recommended: recommended,
      boundary: recommended == 'raise' ? fourBetThresh : continueThresh,
      baseReason: baseReason,
      notes: notes,
      secondaryBoundary: recommended == 'fold' ? fourBetThresh : null,
    );
  }

  // ── Cold-facing a 3-bet (hero hasn't raised) ────────────────────────

  static DrillGradeResult _gradeVs3betCold(
      DrillDecisionContext ctx, String action) {
    final notes = <String>[];
    double continueThresh = 3;
    if (ctx.opener != null &&
        !ctx.opener!.isGenericBot &&
        ctx.opener!.vpip >= 33) {
      continueThresh += 2;
      notes.add('Both raises came from loose players — you can continue '
          'slightly wider than usual, but this is still a premium-only spot.');
    }

    final top = DrillHandStrength.topPercent(ctx.handClass);
    final String recommended;
    if (top <= 1.5) {
      recommended = 'raise';
    } else if (top <= continueThresh) {
      recommended = 'call';
    } else {
      recommended = 'fold';
    }

    final baseReason = recommended == 'fold'
        ? 'A raise and a re-raise in front of you means two strong ranges — ${ctx.handClass} is an easy fold.'
        : '${ctx.handClass} is one of the few hands that can profitably enter a 3-bet pot cold.';

    return _compare(
      ctx: ctx,
      action: action,
      recommended: recommended,
      boundary: continueThresh,
      baseReason: baseReason,
      notes: notes,
      secondaryBoundary: recommended == 'fold' ? 1.5 : null,
    );
  }

  // ── Shared comparison / message building ────────────────────────────

  /// Compares the hero's action to the recommendation. When they differ,
  /// hands within [_closeBand] points of the relevant range boundary grade
  /// as "ok". [secondaryBoundary] covers the raise boundary when the
  /// recommendation is fold (so a near-3-bet-range raise isn't a "mistake").
  static DrillGradeResult _compare({
    required DrillDecisionContext ctx,
    required String action,
    required String recommended,
    required double boundary,
    required String baseReason,
    required List<String> notes,
    double? secondaryBoundary,
  }) {
    // check and call are equivalent "passive continue" when there's nothing
    // to call (BB option spots)
    final normalizedAction =
        (action == 'check' && recommended == 'call') ? 'call' : action;
    final normalizedRecommended =
        (recommended == 'check' && action == 'call' && ctx.toCallBB <= 0)
            ? 'call'
            : recommended;

    final top = DrillHandStrength.topPercent(ctx.handClass);

    DrillGrade grade;
    if (normalizedAction == normalizedRecommended) {
      grade = DrillGrade.correct;
    } else {
      var nearBoundary = (top - boundary).abs() <= _closeBand;
      if (!nearBoundary && secondaryBoundary != null && action == 'raise') {
        nearBoundary = (top - secondaryBoundary).abs() <= _closeBand;
      }
      // Folding the BB option / checking instead of a thin iso is never
      // more than a minor error... but folding when checking was free IS.
      if (action == 'fold' && ctx.toCallBB <= 0) {
        nearBoundary = false;
      }
      grade = nearBoundary ? DrillGrade.ok : DrillGrade.mistake;
    }

    final detail = [if (notes.isNotEmpty) notes.join(' ') else baseReason];
    final String lead;
    switch (grade) {
      case DrillGrade.correct:
        lead = '${_actionWord(recommended)} is the right play.';
      case DrillGrade.ok:
        lead =
            'Close spot — ${_actionWord(recommended).toLowerCase()} is slightly better here.';
      case DrillGrade.mistake:
        lead = '${_actionWord(recommended)} was the play.';
    }

    return DrillGradeResult(
      grade: grade,
      heroAction: action,
      recommendedAction: recommended,
      explanation: '$lead ${detail.join(' ')}',
    );
  }

  /// Demotes a correct raise to "ok" when the sizing is far off, appending a
  /// sizing tip.
  static DrillGradeResult _withSizingNote(
      DrillGradeResult result, String action, double? raiseToBB,
      {required double idealTo,
      required String label,
      required double stackBB}) {
    if (action != 'raise' ||
        raiseToBB == null ||
        result.grade != DrillGrade.correct) {
      return result;
    }
    // Jams are graded on action only — sizing rules don't apply
    if (raiseToBB >= stackBB * 0.9) return result;
    final ratio = raiseToBB / idealTo;
    if (ratio >= 0.7 && ratio <= 1.6) return result;
    final note = ratio < 0.7
        ? 'Size up: a $label around ${idealTo.toStringAsFixed(1)}BB charges the field properly — ${raiseToBB.toStringAsFixed(1)}BB invites the whole table along.'
        : 'That sizing is bigger than it needs to be — around ${idealTo.toStringAsFixed(1)}BB does the same job at a better price.';
    return DrillGradeResult(
      grade: DrillGrade.ok,
      heroAction: result.heroAction,
      recommendedAction: result.recommendedAction,
      explanation: '${result.explanation} $note',
    );
  }

  static DrillVillainProfile? _strongest(
      List<DrillVillainProfile> players,
      bool Function(DrillVillainProfile) where,
      double Function(DrillVillainProfile) by) {
    DrillVillainProfile? best;
    for (final p in players) {
      if (!where(p)) continue;
      if (best == null || by(p) > by(best)) best = p;
    }
    return best;
  }

  static String _pct(double v) => '${v.round()}%';

  static String _posName(String group) {
    switch (group) {
      case 'EP':
        return 'early position';
      case 'MP':
        return 'middle position';
      case 'CO':
        return 'the cutoff';
      case 'BTN':
        return 'the button';
      case 'SB':
        return 'the small blind';
      case 'BB':
        return 'the big blind';
      default:
        return group;
    }
  }

  static String _actionWord(String action) {
    switch (action) {
      case 'raise':
        return 'Raising';
      case 'call':
        return 'Calling';
      case 'check':
        return 'Checking';
      case 'fold':
        return 'Folding';
      default:
        return action;
    }
  }
}
