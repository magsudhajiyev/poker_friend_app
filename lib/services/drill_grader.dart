import '../models/drill_models.dart';
import 'drill_gto_charts.dart';
import 'drill_hand_strength.dart';

/// One recommended line (GTO baseline or exploit-adjusted) for a decision.
class _Line {
  final String action; // 'raise' | 'call' | 'check' | 'fold'
  final double boundary; // primary range % boundary (for the percentile UI)
  final String reason;
  const _Line(this.action, this.boundary, this.reason);
}

/// Grades hero decisions in training drills two ways and shows both:
///
/// 1. **GTO** — an opponent-agnostic baseline driven only by position and
///    stack depth (the "what a solver-ish default would do here" line).
/// 2. **Exploit** — that baseline shifted by the measured tendencies of the
///    actual opponents at the table, with a human note naming the player and
///    the stat.
///
/// The verdict (Correct/Close/Mistake) is graded against the **exploit** line,
/// since exploitation is the whole point of the trainer — but both lines are
/// returned so the divergence is visible and teachable. Ranges are "top X% of
/// combos" cutoffs via [DrillHandStrength].
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

  // ── Decision helpers (thresholds → action) ──────────────────────────

  static _Line _limpLine(
      String hand, double isoThresh, bool canCheck, String reason) {
    final overlimp = isoThresh + 12;
    if (DrillHandStrength.inTopPercent(hand, isoThresh)) {
      return _Line('raise', isoThresh, reason);
    }
    if (canCheck) return _Line('check', isoThresh, reason);
    if (DrillHandStrength.inTopPercent(hand, overlimp)) {
      return _Line('call', overlimp, reason);
    }
    return _Line('fold', overlimp, reason);
  }

  /// Tiered raise/call/fold spot (facing a raise, or a 3-bet).
  static _Line _tieredLine(
      String hand, double raiseThresh, double callThresh, String reason) {
    final top = DrillHandStrength.topPercent(hand);
    if (top <= raiseThresh) return _Line('raise', raiseThresh, reason);
    if (top <= callThresh) return _Line('call', callThresh, reason);
    return _Line('fold', callThresh, reason);
  }

  // ── Unopened pot ────────────────────────────────────────────────────

  static DrillGradeResult _gradeUnopened(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final pos = ctx.positionGroup;
    final hand = ctx.handClass;

    // GTO baseline: an explicit RFI chart, not a strength percentile —
    // small pairs and suited hands open well above their raw-strength rank.
    final gtoSet = DrillGtoCharts.openRange(pos);
    final gtoCoverage = DrillGtoCharts.coverageOf(gtoSet);
    final gtoOpen = gtoSet.contains(hand);
    final gto = _Line(
      gtoOpen ? 'raise' : 'fold',
      gtoCoverage,
      gtoOpen
          ? '$hand is in the GTO opening range from ${_posName(pos)} '
              '(opens ~${_pct(gtoCoverage)} of hands).'
          : '$hand is not a GTO open from ${_posName(pos)} '
              '(opens ~${_pct(gtoCoverage)} of hands).',
    );

    // ── Exploit: widen/tighten the chart for the actual lineup ──
    // Positive widenPct loosens the open range; negative tightens it.
    final notes = <String>[];
    double widenPct = 0;
    final isStealSeat = pos == 'CO' || pos == 'BTN' || pos == 'SB';

    final blinds =
        ctx.blindsBehind.where((b) => !b.profile.isGenericBot).toList();
    if (isStealSeat && blinds.isNotEmpty) {
      final avgVpip =
          blinds.map((b) => b.profile.vpip).reduce((a, b) => a + b) /
              blinds.length;
      final maxThreeBet =
          blinds.map((b) => b.profile.threeBet).reduce((a, b) => a > b ? a : b);
      final names = _nameList(blinds.map((b) => b.profile.name).toList());
      final plural = blinds.length > 1;

      if (avgVpip <= 24) {
        widenPct += ((24 - avgVpip) * 1.1).clamp(0.0, 22.0).toDouble();
        notes.add('$names ${plural ? 'fold' : 'folds'} the blinds a lot '
            '(VPIP ${_pct(avgVpip)}) — steal relentlessly from ${_posName(pos)}, '
            'open any halfway-playable hand.');
      } else if (avgVpip >= 34) {
        widenPct -= 4;
        notes.add('$names ${plural ? 'defend' : 'defends'} the blinds wide '
            '(VPIP ${_pct(avgVpip)}) — your steals get called, so tighten toward '
            'hands that flop well and drop the offsuit junk.');
      }
      if (maxThreeBet >= 11) {
        widenPct -= 6;
        notes.add('Careful — a blind 3-bets ${_pct(maxThreeBet)}, so the very '
            'bottom of your steal range just gets blown off the pot.');
      }
    }

    final behind = ctx.behindDetail.isNotEmpty
        ? ctx.behindDetail
        : ctx.playersBehind
            .map((p) => DrillSeatRef(
                profile: p,
                positionGroup: '',
                isBlind: false,
                isDirectLeft: false))
            .toList();
    DrillSeatRef? aggro;
    for (final r in behind) {
      if (r.profile.isGenericBot || r.profile.threeBet < 10 || r.isBlind) {
        continue;
      }
      if (aggro == null || r.profile.threeBet > aggro.profile.threeBet) {
        aggro = r;
      }
    }
    if (aggro != null) {
      widenPct -= aggro.isDirectLeft ? 8.0 : 4.0;
      final where =
          aggro.isDirectLeft ? 'on your direct left' : 'still to act behind you';
      notes.add('${aggro.profile.name} 3-bets ${_pct(aggro.profile.threeBet)} '
          '$where (${aggro.profile.confidenceLabel}) — tighten your opens and '
          'be ready to 4-bet or fold, don\'t open-fold the bottom of your range.');
    }

    final station = _strongest(
        ctx.playersBehind,
        (p) => p.vpip >= 42 && p.pfr < 15 && !p.isGenericBot,
        (p) => p.vpip);
    if (station != null && aggro == null) {
      widenPct -= 3;
      notes.add('${station.name} calls far too much (VPIP ${_pct(station.vpip)}) '
          '— favour hands that flop strong top pairs over pure steal trash.');
    }

    final exploitSet = widenPct >= 0
        ? DrillGtoCharts.widen(gtoSet, widenPct)
        : DrillGtoCharts.tighten(gtoSet, -widenPct);
    final exploitCoverage = DrillGtoCharts.coverageOf(exploitSet);
    final exploitOpen = exploitSet.contains(hand);
    final exploitReason =
        notes.isEmpty ? _lineupFallbackNote(ctx, isStealSeat) : notes.join(' ');
    final exploit =
        _Line(exploitOpen ? 'raise' : 'fold', exploitCoverage, exploitReason);

    return _finalize(ctx, action, raiseToBB,
        gto: gto, exploit: exploit, sizingIdealTo: 2.5, sizingLabel: 'open');
  }

  static String _lineupFallbackNote(
      DrillDecisionContext ctx, bool isStealSeat) {
    final blinds =
        ctx.blindsBehind.where((b) => !b.profile.isGenericBot).toList();
    if (isStealSeat && blinds.isNotEmpty) {
      final avgVpip =
          blinds.map((b) => b.profile.vpip).reduce((a, b) => a + b) /
              blinds.length;
      final names = _nameList(blinds.map((b) => b.profile.name).toList());
      return '$names in the blinds play a fairly standard VPIP ${_pct(avgVpip)} '
          '— no glaring leak to attack, so the exploit matches the GTO open.';
    }
    final reads = ctx.playersBehind.where((p) => !p.isGenericBot).toList();
    if (reads.isNotEmpty) {
      final avgVpip =
          reads.map((p) => p.vpip).reduce((a, b) => a + b) / reads.length;
      final tone = avgVpip <= 22
          ? 'tight'
          : avgVpip >= 32
              ? 'loose'
              : 'fairly standard';
      return 'The players behind you are $tone (avg VPIP ${_pct(avgVpip)}) — '
          'no big deviation from the GTO open is warranted.';
    }
    return 'No reads yet on the players behind you — the exploit matches the '
        'GTO baseline until they show tendencies.';
  }

  // ── Limped pot ──────────────────────────────────────────────────────

  static DrillGradeResult _gradeVsLimpers(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final pos = ctx.positionGroup;
    final limperCount = ctx.limpers.length;
    final canCheck = ctx.toCallBB <= 0;
    final plural = limperCount > 1;

    double baseIso = (_openThreshold[pos] ?? 20) + 4 + 2.0 * limperCount;
    if (pos == 'BB') baseIso = 16 + 2.0 * limperCount;
    baseIso = baseIso.clamp(10.0, 65.0).toDouble();
    final gto = _limpLine(
        ctx.handClass,
        baseIso,
        canCheck,
        'GTO iso-raises about the top ${_pct(baseIso)} over '
        '$limperCount limper${plural ? 's' : ''} and takes a free flop with the rest.');

    // Exploit
    final notes = <String>[];
    double isoThresh = baseIso;
    final loosePassive = _strongest(ctx.limpers,
        (p) => p.vpip >= 38 && p.pfr <= 15 && !p.isGenericBot, (p) => p.vpip);
    if (loosePassive != null) {
      isoThresh += 4;
      notes.add('${loosePassive.name} limps into most pots '
          '(VPIP ${_pct(loosePassive.vpip)}, ${loosePassive.confidenceLabel}) — '
          'isolate wide and take the betting lead.');
    }
    isoThresh = isoThresh.clamp(10.0, 65.0).toDouble();
    final exploitReason = notes.isEmpty
        ? 'The limper${plural ? 's are' : ' is'} nothing special — iso a standard '
            'value range and check back the rest.'
        : notes.join(' ');
    final exploit = _limpLine(ctx.handClass, isoThresh, canCheck, exploitReason);

    return _finalize(ctx, action, raiseToBB,
        gto: gto,
        exploit: exploit,
        sizingIdealTo: 3.0 + limperCount,
        sizingLabel: 'iso-raise');
  }

  // ── Facing a single raise ───────────────────────────────────────────

  static DrillGradeResult _gradeVsRaise(
      DrillDecisionContext ctx, String action, double? raiseToBB) {
    final pos = ctx.positionGroup;
    final opener = ctx.opener;

    // Structural baseline (position + stack) = GTO
    double baseThreeBet = 5;
    double baseCall = switch (pos) {
      'BB' => 28,
      'SB' => 10,
      _ => 14,
    };
    String? stackNote;
    if (ctx.stackBB <= 25) {
      baseThreeBet += 2;
      baseCall = pos == 'BB' ? 18 : 6;
      stackNote = 'At ${ctx.stackBB.toStringAsFixed(0)}BB this is '
          '3-bet-jam-or-fold territory — flatting burns your stack.';
    }
    baseThreeBet = baseThreeBet.clamp(2.0, 30.0).toDouble();
    baseCall = baseCall.clamp(baseThreeBet, 45.0).toDouble();
    final gtoReason =
        'GTO defends about the top ${_pct(baseCall)} versus an open, '
        '3-betting the top ${_pct(baseThreeBet)}.${stackNote != null ? ' $stackNote' : ''}';
    final gto = _tieredLine(ctx.handClass, baseThreeBet, baseCall, gtoReason);

    // Exploit: opponent reads on top of the structural baseline
    final notes = <String>[];
    double threeBetThresh = baseThreeBet;
    double callThresh = baseCall;
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
    threeBetThresh = threeBetThresh.clamp(2.0, 30.0).toDouble();
    callThresh = callThresh.clamp(threeBetThresh, 45.0).toDouble();
    final exploitReason = notes.isNotEmpty
        ? notes.join(' ')
        : (stackNote ??
            'No strong read on the opener — defend a solid default range.');
    final exploit =
        _tieredLine(ctx.handClass, threeBetThresh, callThresh, exploitReason);

    return _finalize(ctx, action, raiseToBB,
        gto: gto,
        exploit: exploit,
        secondaryBoundary: threeBetThresh,
        sizingIdealTo: ctx.currentBetBB * 3,
        sizingLabel: '3-bet');
  }

  // ── Hero opened, now facing a re-raise ──────────────────────────────

  static DrillGradeResult _gradeVs3betAsAggressor(
      DrillDecisionContext ctx, String action) {
    final threeBettor = ctx.opener;

    double baseFourBet = 2.5;
    double baseContinue = 9;
    String? stackNote;
    if (ctx.stackBB <= 25) {
      stackNote =
          'Short-stacked: continuing means getting it in — jam or fold, never flat.';
    }
    baseFourBet = baseFourBet.clamp(1.0, 10.0).toDouble();
    baseContinue = baseContinue.clamp(baseFourBet, 25.0).toDouble();
    final gto = _tieredLine(
        ctx.handClass,
        baseFourBet,
        baseContinue,
        'GTO continues about the top ${_pct(baseContinue)} against a 3-bet, '
        '4-betting the top ${_pct(baseFourBet)}.${stackNote != null ? ' $stackNote' : ''}');

    final notes = <String>[];
    double fourBetThresh = baseFourBet;
    double continueThresh = baseContinue;
    if (threeBettor != null && !threeBettor.isGenericBot) {
      if (threeBettor.threeBet >= 9) {
        fourBetThresh += 1.5;
        continueThresh += 5;
        notes.add('${threeBettor.name} 3-bets ${_pct(threeBettor.threeBet)} '
            '(${threeBettor.confidenceLabel}) — too wide to fold to, continue lighter and 4-bet more.');
      } else if (threeBettor.threeBet <= 4.5) {
        continueThresh -= 3;
        notes.add('${threeBettor.name} almost never 3-bets '
            '(${_pct(threeBettor.threeBet)}) — this is the top of the deck, fold everything but premiums.');
      }
    }
    fourBetThresh = fourBetThresh.clamp(1.0, 10.0).toDouble();
    continueThresh = continueThresh.clamp(fourBetThresh, 25.0).toDouble();
    final exploitReason = notes.isNotEmpty
        ? notes.join(' ')
        : (stackNote ??
            'No strong read on the 3-bettor — continue a solid default range.');
    final exploit =
        _tieredLine(ctx.handClass, fourBetThresh, continueThresh, exploitReason);

    return _finalize(ctx, action, null,
        gto: gto, exploit: exploit, secondaryBoundary: fourBetThresh);
  }

  // ── Cold-facing a 3-bet (hero hasn't raised) ────────────────────────

  static DrillGradeResult _gradeVs3betCold(
      DrillDecisionContext ctx, String action) {
    const baseContinue = 3.0;
    const raiseThresh = 1.5;
    final gto = _tieredLine(ctx.handClass, raiseThresh, baseContinue,
        'GTO enters a cold 3-bet pot with only premiums — about the top ${_pct(baseContinue)}.');

    final notes = <String>[];
    double continueThresh = baseContinue;
    if (ctx.opener != null &&
        !ctx.opener!.isGenericBot &&
        ctx.opener!.vpip >= 33) {
      continueThresh += 2;
      notes.add('${ctx.opener!.name} and the raiser are both loose, so you can '
          'continue a touch wider — but this is still a premium-only spot.');
    }
    continueThresh = continueThresh.clamp(raiseThresh, 25.0).toDouble();
    final exploitReason = notes.isNotEmpty
        ? notes.join(' ')
        : 'A raise and a re-raise mean two strong ranges — fold everything but premiums.';
    final exploit =
        _tieredLine(ctx.handClass, raiseThresh, continueThresh, exploitReason);

    return _finalize(ctx, action, null,
        gto: gto, exploit: exploit, secondaryBoundary: raiseThresh);
  }

  // ── Verdict assembly ────────────────────────────────────────────────

  /// Grades the hero's [action] against the **exploit** line and packages
  /// both lines. [secondaryBoundary] lets a near-raise-threshold raise count
  /// as "close" when the exploit line says fold.
  static DrillGradeResult _finalize(
    DrillDecisionContext ctx,
    String action,
    double? raiseToBB, {
    required _Line gto,
    required _Line exploit,
    double? secondaryBoundary,
    double? sizingIdealTo,
    String? sizingLabel,
  }) {
    final top = DrillHandStrength.topPercent(ctx.handClass);

    // check/call are the same "passive continue" when nothing is owed
    final normAction =
        (action == 'check' && exploit.action == 'call') ? 'call' : action;
    final normRec =
        (exploit.action == 'check' && action == 'call' && ctx.toCallBB <= 0)
            ? 'call'
            : exploit.action;

    DrillGrade grade;
    if (normAction == normRec) {
      grade = DrillGrade.correct;
    } else {
      var near = (top - exploit.boundary).abs() <= _closeBand;
      if (!near && secondaryBoundary != null && action == 'raise') {
        near = (top - secondaryBoundary).abs() <= _closeBand;
      }
      if (action == 'fold' && ctx.toCallBB <= 0) near = false;
      grade = near ? DrillGrade.ok : DrillGrade.mistake;
    }

    final String lead;
    switch (grade) {
      case DrillGrade.correct:
        lead = '${_actionWord(exploit.action)} is the exploitative play.';
      case DrillGrade.ok:
        lead =
            'Close — ${_actionWord(exploit.action).toLowerCase()} is slightly better against this lineup.';
      case DrillGrade.mistake:
        lead = '${_actionWord(exploit.action)} was the exploitative play.';
    }

    var result = DrillGradeResult(
      grade: grade,
      heroAction: action,
      recommendedAction: exploit.action,
      explanation: '$lead ${exploit.reason}',
      handTopPercent: top,
      rangePercent: exploit.boundary,
      gtoAction: gto.action,
      gtoRangePercent: gto.boundary,
      gtoReason: gto.reason,
      exploitAction: exploit.action,
      exploitRangePercent: exploit.boundary,
      exploitReason: exploit.reason,
    );

    if (sizingIdealTo != null && sizingLabel != null) {
      result = _withSizingNote(result, action, raiseToBB,
          idealTo: sizingIdealTo, label: sizingLabel, stackBB: ctx.stackBB);
    }
    return result;
  }

  /// Demotes a correct raise to "ok" when the sizing is far off, appending a
  /// sizing tip to both the headline and the exploit reasoning.
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
    return result.copyWith(
      grade: DrillGrade.ok,
      explanation: '${result.explanation} $note',
      exploitReason: '${result.exploitReason} $note',
    );
  }

  // ── Small helpers ───────────────────────────────────────────────────

  /// Joins names like "Tom", "Tom & Dave", "Tom, Dave & Sue".
  static String _nameList(List<String> names) {
    if (names.isEmpty) return 'They';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} & ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
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
