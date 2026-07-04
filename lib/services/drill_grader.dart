import '../models/drill_models.dart';
import 'drill_gto_charts.dart';
import 'drill_insights.dart';
import 'drill_nash_pushfold.dart';

/// One recommended line (GTO baseline or exploit-adjusted) for a decision.
class _Line {
  final String action; // 'raise' | 'call' | 'check' | 'fold'
  final double rangePct; // coverage % of the primary range (for UI)
  final String reason;
  final bool fromReads; // reason cites a specific opponent read
  const _Line(this.action, this.rangePct, this.reason,
      {this.fromReads = false});
}

/// Grades hero decisions two ways and shows both:
///
/// 1. **GTO** — chart/table membership, no formulas:
///    - >60BB: curated ~100BB charts (RFI, defend-vs-open keyed by BOTH
///      positions, vs-3-bet by opener seat).
///    - 20–60BB: the same charts with flat-calls tightened (~40BB profile).
///    - ≤20BB: self-computed Nash push/fold tables (exact for SB-vs-BB,
///      fold-through approximation for earlier seats).
/// 2. **Exploit** — the baseline range widened/tightened along the
///    chart-derived playability ordering according to opponent reads.
///
/// Every grade carries a [DrillGradeResult.trace]: which chart produced the
/// baseline, each adjustment applied, the membership checks, and the verdict
/// math — logged with debugPrint in debug builds.
class DrillGrader {
  DrillGrader._();

  /// Hands within this many playability-percentile points of a range edge
  /// grade as "ok" instead of "mistake" — close spots shouldn't punish.
  static const double _closeBand = 4.0;

  static DrillGradeResult grade(DrillDecisionContext ctx, String heroAction,
      {double? raiseToBB}) {
    final trace = <String>[
      'spot: ${ctx.scenario.name} | hero ${ctx.positionGroup} | '
          'hand ${ctx.handClass} (playability top '
          '${DrillGtoCharts.playabilityPercent(ctx.handClass).toStringAsFixed(0)}%) | '
          'stack ${ctx.stackBB.toStringAsFixed(0)}BB | '
          'profile ${DrillGtoCharts.profileFor(ctx.stackBB)}',
    ];
    switch (ctx.scenario) {
      case DrillScenario.unopened:
        return _gradeUnopened(ctx, heroAction, raiseToBB, trace);
      case DrillScenario.vsLimpers:
        return _gradeVsLimpers(ctx, heroAction, raiseToBB, trace);
      case DrillScenario.vsRaise:
        return _gradeVsRaise(ctx, heroAction, raiseToBB, trace);
      case DrillScenario.vs3betAsAggressor:
        return _gradeVs3betAsAggressor(ctx, heroAction, trace);
      case DrillScenario.vs3betCold:
        return _gradeVs3betCold(ctx, heroAction, trace);
    }
  }

  // ── Unopened pot ────────────────────────────────────────────────────

  static DrillGradeResult _gradeUnopened(DrillDecisionContext ctx,
      String action, double? raiseToBB, List<String> trace) {
    final pos = ctx.positionGroup;
    final profile = DrillGtoCharts.profileFor(ctx.stackBB);

    // Baseline set + provenance
    Set<String> gtoSet;
    String baseLabel;
    if (profile == 'nash') {
      final s = DrillNashPushfold.nearestStack(ctx.stackBB);
      gtoSet = DrillNashPushfold.jamRange(pos, ctx.stackBB);
      baseLabel = DrillNashPushfold.isExact(pos)
          ? 'Nash push/fold (exact), $pos @ ${s.toInt()}BB'
          : 'Nash push/fold (fold-through approx.), $pos @ ${s.toInt()}BB';
    } else {
      gtoSet = DrillGtoCharts.openRange(pos);
      baseLabel = 'RFI chart $pos @ $profile';
      if (ctx.anteMode) {
        gtoSet = DrillGtoCharts.widen(gtoSet, DrillGtoCharts.anteWidenPct);
        baseLabel = '$baseLabel + ante';
        trace.add('ante in play: baseline widened '
            '+${DrillGtoCharts.anteWidenPct.toStringAsFixed(0)}% for the dead money');
      }
    }
    trace.add('baseline: $baseLabel — '
        '${DrillGtoCharts.coverageOf(gtoSet).toStringAsFixed(1)}% of hands');

    final gtoOpen = gtoSet.contains(ctx.handClass);
    trace.add('gto membership: ${ctx.handClass} '
        '${gtoOpen ? 'IN' : 'NOT IN'} baseline');
    // SB with an ante is NOT raise-or-fold: the dead money makes the small
    // blind complete nearly everything playable instead of folding.
    final sbCompleteSpot = ctx.anteMode && profile != 'nash' && pos == 'SB';
    final gtoCompletes = sbCompleteSpot &&
        !gtoOpen &&
        DrillGtoCharts.sbCompletes(ctx.handClass);
    if (sbCompleteSpot) {
      trace.add('sb complete strategy: continue cutoff = top '
          '${DrillGtoCharts.sbCompleteCutoff.toStringAsFixed(0)}% playability; '
          '${ctx.handClass} ${DrillGtoCharts.sbCompletes(ctx.handClass) ? 'COMPLETES' : 'FOLDS'} '
          'when not raising');
    }
    final verb = profile == 'nash' ? 'jams' : 'opens';
    final gto = _Line(
      gtoOpen ? 'raise' : (gtoCompletes ? 'call' : 'fold'),
      gtoCompletes
          ? DrillGtoCharts.sbCompleteCutoff
          : DrillGtoCharts.coverageOf(gtoSet),
      gtoOpen
          ? '${ctx.handClass} is in the GTO $verb range from ${_posName(pos)} '
              '($baseLabel).'
          : gtoCompletes
              ? '${ctx.handClass} is too weak to open-raise, but with the '
                  'ante in the pot the small blind completes almost every '
                  'playable hand instead of folding ($baseLabel).'
              : '${ctx.handClass} is not a GTO $verb from ${_posName(pos)} '
                  '($baseLabel).',
    );

    // Exploit: widen/tighten along the playability ordering
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
        final d = ((24 - avgVpip) * 1.1).clamp(0.0, 22.0).toDouble();
        widenPct += d;
        trace.add('exploit: tight blinds (avg VPIP '
            '${avgVpip.toStringAsFixed(0)}) → widen +${d.toStringAsFixed(1)}%');
        notes.add('$names ${plural ? 'fold' : 'folds'} the blinds a lot '
            '(VPIP ${_pct(avgVpip)}) — steal relentlessly from ${_posName(pos)}.');
      } else if (avgVpip >= 34) {
        widenPct -= 4;
        trace.add('exploit: wide-defending blinds (avg VPIP '
            '${avgVpip.toStringAsFixed(0)}) → tighten -4%');
        notes.add('$names ${plural ? 'defend' : 'defends'} wide '
            '(VPIP ${_pct(avgVpip)}) — drop the weakest steals.');
      }
      if (maxThreeBet >= 11) {
        widenPct -= 6;
        trace.add('exploit: 3-bet-happy blind (${_pct(maxThreeBet)}) → tighten -6%');
        notes.add('A blind 3-bets ${_pct(maxThreeBet)} — the bottom of your '
            'range gets blown off the pot.');
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
      final d = aggro.isDirectLeft ? 8.0 : 4.0;
      widenPct -= d;
      trace.add('exploit: aggro 3-bettor '
          '${aggro.isDirectLeft ? 'on direct left' : 'behind'} '
          '(${_pct(aggro.profile.threeBet)}) → tighten -$d%');
      notes.add('${aggro.profile.name} 3-bets ${_pct(aggro.profile.threeBet)} '
          '${aggro.isDirectLeft ? 'on your direct left' : 'behind you'} '
          '(${aggro.profile.confidenceLabel}) — tighten and be ready to play back.');
    }

    final station = _strongest(
        ctx.playersBehind,
        (p) => p.vpip >= 42 && p.pfr < 15 && !p.isGenericBot,
        (p) => p.vpip);
    if (station != null && aggro == null) {
      widenPct -= 3;
      trace.add('exploit: station behind (VPIP ${_pct(station.vpip)}) → tighten -3%');
      notes.add('${station.name} calls far too much '
          '(VPIP ${_pct(station.vpip)}) — favour hands that flop well.');
    }

    final exploitSet = widenPct >= 0
        ? DrillGtoCharts.widen(gtoSet, widenPct)
        : DrillGtoCharts.tighten(gtoSet, -widenPct);
    trace.add('exploit range: ${widenPct >= 0 ? '+' : ''}'
        '${widenPct.toStringAsFixed(1)}% → '
        '${DrillGtoCharts.coverageOf(exploitSet).toStringAsFixed(1)}% of hands; '
        '${ctx.handClass} ${exploitSet.contains(ctx.handClass) ? 'IN' : 'NOT IN'}');
    final exploitOpen = exploitSet.contains(ctx.handClass);
    final exploitCompletes = sbCompleteSpot &&
        !exploitOpen &&
        DrillGtoCharts.sbCompletes(ctx.handClass);
    final exploitReason = notes.isEmpty
        ? 'No exploitable reads behind you — the exploit matches the GTO baseline.'
        : notes.join(' ');
    final exploit = _Line(
        exploitOpen ? 'raise' : (exploitCompletes ? 'call' : 'fold'),
        exploitCompletes
            ? DrillGtoCharts.sbCompleteCutoff
            : DrillGtoCharts.coverageOf(exploitSet),
        exploitReason,
        fromReads: notes.isNotEmpty);

    return _finalize(ctx, action, raiseToBB,
        gto: gto,
        exploit: exploit,
        exploitEdgePct: exploitCompletes
            ? DrillGtoCharts.sbCompleteCutoff
            : DrillGtoCharts.coverageOf(exploitSet),
        secondaryEdgePct:
            exploitCompletes ? DrillGtoCharts.coverageOf(exploitSet) : null,
        mixedRaiseOk: exploitCompletes,
        trace: trace,
        sizingIdealTo: profile == 'nash' ? null : 2.5,
        sizingLabel: 'open');
  }

  // ── Limped pot ──────────────────────────────────────────────────────

  static DrillGradeResult _gradeVsLimpers(DrillDecisionContext ctx,
      String action, double? raiseToBB, List<String> trace) {
    final pos = ctx.positionGroup;
    final limperCount = ctx.limpers.length;
    final canCheck = ctx.toCallBB <= 0;
    final plural = limperCount > 1;

    // Baseline iso = the position's open range widened for dead money
    final base = pos == 'BB'
        ? DrillGtoCharts.tighten(DrillGtoCharts.openRange('CO'), 10)
        : DrillGtoCharts.openRange(pos);
    // Dead money widens the iso for the FIRST limper, but each additional
    // limper means more players to get through — iso TIGHTER multiway
    // (sizing scales up instead; see suggested sizes).
    final isoDelta = 4.0 - 2.0 * (limperCount - 1);
    final isoBase = isoDelta >= 0
        ? DrillGtoCharts.widen(base, isoDelta)
        : DrillGtoCharts.tighten(base, -isoDelta);
    trace.add('baseline: iso chart = ${pos == 'BB' ? 'CO-open−10%' : 'RFI $pos'} '
        '${isoDelta >= 0 ? '+' : ''}${isoDelta.toStringAsFixed(0)}% for '
        '$limperCount limper${plural ? 's' : ''} '
        '(first widens, extras tighten) → '
        '${DrillGtoCharts.coverageOf(isoBase).toStringAsFixed(1)}%');
    final gto = _limpLine(ctx, isoBase, canCheck, trace, 'gto');
    final gtoLine = _Line(
        gto,
        DrillGtoCharts.coverageOf(isoBase),
        'Iso-raise about the top '
        '${_pct(DrillGtoCharts.coverageOf(isoBase))} over '
        '$limperCount limper${plural ? 's' : ''}; take free flops with the rest.');

    // Exploit
    final notes = <String>[];
    var isoSet = isoBase;
    final loosePassive = _strongest(ctx.limpers,
        (p) => p.vpip >= 38 && p.pfr <= 15 && !p.isGenericBot, (p) => p.vpip);
    if (loosePassive != null) {
      isoSet = DrillGtoCharts.widen(isoSet, 4);
      trace.add('exploit: loose-passive limper '
          '(VPIP ${_pct(loosePassive.vpip)}) → widen iso +4%');
      notes.add('${loosePassive.name} limps into most pots '
          '(VPIP ${_pct(loosePassive.vpip)}, ${loosePassive.confidenceLabel}) — '
          'isolate wide and take the lead.');
    }
    final exploitAction = _limpLine(ctx, isoSet, canCheck, trace, 'exploit');
    final exploitLine = _Line(
        exploitAction,
        DrillGtoCharts.coverageOf(isoSet),
        notes.isEmpty
            ? 'The limper${plural ? 's are' : ' is'} unremarkable — iso a '
                'standard range and check back the rest.'
            : notes.join(' '),
        fromReads: notes.isNotEmpty);

    return _finalize(ctx, action, raiseToBB,
        gto: gtoLine,
        exploit: exploitLine,
        exploitEdgePct: DrillGtoCharts.coverageOf(isoSet),
        trace: trace,
        sizingIdealTo: 3.0 + limperCount,
        sizingLabel: 'iso-raise');
  }

  static String _limpLine(DrillDecisionContext ctx, Set<String> iso,
      bool canCheck, List<String> trace, String tag) {
    final inIso = iso.contains(ctx.handClass);
    final overlimp =
        DrillGtoCharts.widen(iso, 12).contains(ctx.handClass) && !inIso;
    trace.add('$tag membership: iso=${inIso ? 'IN' : 'out'}'
        '${canCheck ? '' : ', overlimp=${overlimp ? 'IN' : 'out'}'}');
    if (inIso) return 'raise';
    if (canCheck) return 'check';
    if (overlimp) return 'call';
    return 'fold';
  }

  // ── Facing a single raise ───────────────────────────────────────────

  static DrillGradeResult _gradeVsRaise(DrillDecisionContext ctx,
      String action, double? raiseToBB, List<String> trace) {
    final pos = ctx.positionGroup;
    final openerPos = ctx.openerPosGroup.isEmpty ? 'CO' : ctx.openerPosGroup;
    final profile = DrillGtoCharts.profileFor(ctx.stackBB);

    // Facing an (effective) jam → Nash call table, exact science
    final facingJam = ctx.toCallBB >= ctx.stackBB * 0.7;
    if (profile == 'nash' && facingJam) {
      final s = DrillNashPushfold.nearestStack(ctx.stackBB);
      final callSet = DrillNashPushfold.callVsJamRange(ctx.stackBB);
      trace.add('baseline: Nash call-vs-jam @ ${s.toInt()}BB '
          '(exact for BB vs SB; used as reference for other seats) — '
          '${DrillGtoCharts.coverageOf(callSet).toStringAsFixed(1)}%');
      final inCall = callSet.contains(ctx.handClass);
      trace.add('membership: ${ctx.handClass} ${inCall ? 'IN' : 'NOT IN'} call range');
      final line = _Line(
          inCall ? 'call' : 'fold',
          DrillGtoCharts.coverageOf(callSet),
          inCall
              ? '${ctx.handClass} is a Nash call vs a jam at this depth.'
              : '${ctx.handClass} is below the Nash calling threshold vs a jam.');
      // Exploit: vs a maniac jammer call wider; vs a nit tighter
      var callSetX = callSet;
      final notes = <String>[];
      final o = ctx.opener;
      if (o != null && !o.isGenericBot) {
        if (o.pfr >= 28 || o.archetype == 'Maniac') {
          callSetX = DrillGtoCharts.widen(callSet, 5);
          trace.add('exploit: maniac jammer (PFR ${_pct(o.pfr)}) → call +5%');
          notes.add('${o.name} shoves wide (${o.confidenceLabel}) — call lighter.');
        } else if (o.vpip <= 17) {
          callSetX = DrillGtoCharts.tighten(callSet, 4);
          trace.add('exploit: nit jammer (VPIP ${_pct(o.vpip)}) → call -4%');
          notes.add('${o.name} only jams premiums — fold the marginal calls.');
        }
      }
      final inX = callSetX.contains(ctx.handClass);
      final lineX = _Line(
          inX ? 'call' : 'fold',
          DrillGtoCharts.coverageOf(callSetX),
          notes.isEmpty ? 'No read on the jammer — Nash is the play.' : notes.join(' '),
          fromReads: notes.isNotEmpty);
      return _finalize(ctx, action, raiseToBB,
          gto: line,
          exploit: lineX,
          exploitEdgePct: DrillGtoCharts.coverageOf(callSetX),
          trace: trace);
    }

    // Chart defend, keyed by BOTH positions
    final resolved = DrillGtoCharts.defendFor(pos, openerPos);
    var chart = resolved?.$1 ??
        DefendChart(
            threeBet: DrillGtoCharts.tighten(DrillGtoCharts.openRange(pos), 30),
            call: <String>{});
    final usedOpener = resolved?.$2 ?? openerPos;
    if (profile != '100bb') {
      chart = DrillGtoCharts.defendAt40bb(chart);
    }
    if (ctx.heroLimped) {
      trace.add('note: hero LIMPED earlier — grading with the cold-defend '
          'chart (limp-defend ranges are an approximation here)');
    }
    trace.add('baseline: defend chart $pos vs $usedOpener open @ $profile — '
        '3bet ${DrillGtoCharts.coverageOf(chart.threeBet).toStringAsFixed(1)}%, '
        'call ${DrillGtoCharts.coverageOf(chart.call).toStringAsFixed(1)}%');

    String memberOf(DefendChart c) => c.threeBet.contains(ctx.handClass)
        ? 'raise'
        : c.call.contains(ctx.handClass)
            ? 'call'
            : 'fold';

    final gtoAction = memberOf(chart);
    trace.add('gto membership: ${ctx.handClass} → $gtoAction');
    final gto = _Line(
        gtoAction,
        DrillGtoCharts.coverageOf(chart.continueRange),
        switch (gtoAction) {
          'raise' => '${ctx.handClass} is in the $pos 3-bet range vs '
              'a $usedOpener open.',
          'call' => '${ctx.handClass} flats vs a $usedOpener open from $pos.',
          _ => '${ctx.handClass} is not in the $pos defend range vs '
              'a $usedOpener open.',
        });

    // Exploit deltas on the two sets
    final notes = <String>[];
    var threeBetSet = chart.threeBet;
    var callSet = chart.call;
    final o = ctx.opener;
    if (o != null && !o.isGenericBot) {
      if (o.fold3bet >= 60) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 6);
        trace.add('exploit: opener folds to 3-bets ${_pct(o.fold3bet)} → 3bet +6%');
        notes.add('${o.name} folds to 3-bets ${_pct(o.fold3bet)} '
            '(${o.confidenceLabel}) — 3-bet him relentlessly.');
      }
      if (o.vpip >= 33) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 4);
        callSet = DrillGtoCharts.widen(callSet, 4);
        trace.add('exploit: loose opener (VPIP ${_pct(o.vpip)}) → 3bet +4%, call +4%');
        notes.add('${o.name} opens loose (VPIP ${_pct(o.vpip)}) — widen value.');
      } else if (o.vpip <= 17) {
        threeBetSet = DrillGtoCharts.tighten(threeBetSet, 2);
        callSet = DrillGtoCharts.tighten(callSet, 5);
        trace.add('exploit: nitty opener (VPIP ${_pct(o.vpip)}) → 3bet -2%, call -5%');
        notes.add('${o.name} plays ${_pct(o.vpip)} of hands — respect his raises.');
      }
      if (o.archetype == 'Maniac' || o.pfr >= 28) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 5);
        callSet = DrillGtoCharts.widen(callSet, 5);
        trace.add('exploit: maniac opener (PFR ${_pct(o.pfr)}) → 3bet +5%, call +5%');
        notes.add('${o.name} raises ${_pct(o.pfr)} of hands — play back wider.');
      }
    }
    final chartX = DefendChart(threeBet: threeBetSet, call: callSet);
    final exploitAction = memberOf(chartX);
    trace.add('exploit membership: ${ctx.handClass} → $exploitAction');
    final exploit = _Line(
        exploitAction,
        DrillGtoCharts.coverageOf(chartX.continueRange),
        notes.isEmpty
            ? 'No strong read on the opener — defend the chart range.'
            : notes.join(' '),
        fromReads: notes.isNotEmpty);

    return _finalize(ctx, action, raiseToBB,
        gto: gto,
        exploit: exploit,
        exploitEdgePct: DrillGtoCharts.coverageOf(chartX.continueRange),
        secondaryEdgePct: DrillGtoCharts.coverageOf(chartX.threeBet),
        trace: trace,
        sizingIdealTo: ctx.currentBetBB * 3,
        sizingLabel: '3-bet');
  }

  // ── Hero opened, now facing a re-raise ──────────────────────────────

  static DrillGradeResult _gradeVs3betAsAggressor(
      DrillDecisionContext ctx, String action, List<String> trace) {
    final pos = ctx.positionGroup;
    final profile = DrillGtoCharts.profileFor(ctx.stackBB);
    var chart = DrillGtoCharts.vs3betFor(pos);
    if (profile != '100bb') {
      chart = Vs3BetChart(
        fourBet: chart.fourBet,
        call: profile == 'nash'
            ? <String>{} // jam-or-fold: flats disappear
            : DrillGtoCharts.tighten(
                chart.call, DrillGtoCharts.coverageOf(chart.call) * 0.35),
      );
    }
    trace.add('baseline: vs-3bet chart (opened from $pos) @ $profile — '
        '4bet ${DrillGtoCharts.coverageOf(chart.fourBet).toStringAsFixed(1)}%, '
        'call ${DrillGtoCharts.coverageOf(chart.call).toStringAsFixed(1)}%');

    String memberOf(Vs3BetChart c) => c.fourBet.contains(ctx.handClass)
        ? 'raise'
        : c.call.contains(ctx.handClass)
            ? 'call'
            : 'fold';

    final gtoAction = memberOf(chart);
    trace.add('gto membership: ${ctx.handClass} → $gtoAction');
    final gto = _Line(
        gtoAction,
        DrillGtoCharts.coverageOf(chart.continueRange),
        switch (gtoAction) {
          'raise' => '${ctx.handClass} 4-bets from the $pos opening range.',
          'call' => '${ctx.handClass} continues vs the 3-bet.',
          _ => 'Opening ${ctx.handClass} was fine, but it folds to a 3-bet.',
        });

    final notes = <String>[];
    var fourBetSet = chart.fourBet;
    var callSet = chart.call;
    final tb = ctx.opener;
    if (tb != null && !tb.isGenericBot) {
      if (tb.threeBet >= 9) {
        fourBetSet = DrillGtoCharts.widen(fourBetSet, 2);
        callSet = DrillGtoCharts.widen(callSet, 5);
        trace.add('exploit: wide 3-bettor (${_pct(tb.threeBet)}) → 4bet +2%, call +5%');
        notes.add('${tb.name} 3-bets ${_pct(tb.threeBet)} '
            '(${tb.confidenceLabel}) — continue lighter, 4-bet more.');
      } else if (tb.threeBet <= 4.5) {
        callSet = DrillGtoCharts.tighten(
            callSet, DrillGtoCharts.coverageOf(callSet) * 0.4);
        trace.add('exploit: rare 3-bettor (${_pct(tb.threeBet)}) → call -40%');
        notes.add('${tb.name} almost never 3-bets (${_pct(tb.threeBet)}) — '
            'this is the top of the deck, fold all but premiums.');
      }
    }
    final chartX = Vs3BetChart(fourBet: fourBetSet, call: callSet);
    final exploitAction = memberOf(chartX);
    trace.add('exploit membership: ${ctx.handClass} → $exploitAction');
    final exploit = _Line(
        exploitAction,
        DrillGtoCharts.coverageOf(chartX.continueRange),
        notes.isEmpty
            ? 'No strong read on the 3-bettor — continue the chart range.'
            : notes.join(' '),
        fromReads: notes.isNotEmpty);

    return _finalize(ctx, action, null,
        gto: gto,
        exploit: exploit,
        exploitEdgePct: DrillGtoCharts.coverageOf(chartX.continueRange),
        secondaryEdgePct: DrillGtoCharts.coverageOf(chartX.fourBet),
        trace: trace);
  }

  // ── Cold-facing a 3-bet ─────────────────────────────────────────────

  static DrillGradeResult _gradeVs3betCold(
      DrillDecisionContext ctx, String action, List<String> trace) {
    var cont = DrillGtoCharts.coldVs3betContinue;
    final raise = DrillGtoCharts.coldVs3betRaise;
    trace.add('baseline: cold-vs-3bet chart — continue '
        '${DrillGtoCharts.coverageOf(cont).toStringAsFixed(1)}%');
    String memberOf(Set<String> c) => raise.contains(ctx.handClass)
        ? 'raise'
        : c.contains(ctx.handClass)
            ? 'call'
            : 'fold';
    final gtoAction = memberOf(cont);
    trace.add('gto membership: ${ctx.handClass} → $gtoAction');
    final gto = _Line(
        gtoAction,
        DrillGtoCharts.coverageOf(cont),
        gtoAction == 'fold'
            ? 'A raise and a re-raise ahead — ${ctx.handClass} is an easy fold.'
            : '${ctx.handClass} is strong enough to enter a 3-bet pot cold.');

    final notes = <String>[];
    if (ctx.opener != null &&
        !ctx.opener!.isGenericBot &&
        ctx.opener!.vpip >= 33) {
      cont = DrillGtoCharts.widen(cont, 2);
      trace.add('exploit: loose aggressors → continue +2%');
      notes.add('Both raises came from loose players — continue slightly '
          'wider, but this stays premium-only.');
    }
    final exploitAction = memberOf(cont);
    trace.add('exploit membership: ${ctx.handClass} → $exploitAction');
    final exploit = _Line(
        exploitAction,
        DrillGtoCharts.coverageOf(cont),
        notes.isEmpty
            ? 'Two strong ranges ahead — stick to premiums.'
            : notes.join(' '),
        fromReads: notes.isNotEmpty);

    return _finalize(ctx, action, null,
        gto: gto,
        exploit: exploit,
        exploitEdgePct: DrillGtoCharts.coverageOf(cont),
        secondaryEdgePct: DrillGtoCharts.coverageOf(raise),
        trace: trace);
  }

  // ── Verdict assembly ────────────────────────────────────────────────

  static DrillGradeResult _finalize(
    DrillDecisionContext ctx,
    String action,
    double? raiseToBB, {
    required _Line gto,
    required _Line exploit,
    required double exploitEdgePct,
    double? secondaryEdgePct,
    bool mixedRaiseOk = false,
    required List<String> trace,
    double? sizingIdealTo,
    String? sizingLabel,
  }) {
    final play = DrillGtoCharts.playabilityPercent(ctx.handClass);

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
      var near = (play - exploitEdgePct).abs() <= _closeBand;
      if (!near && secondaryEdgePct != null && action == 'raise') {
        near = (play - secondaryEdgePct).abs() <= _closeBand;
      }
      if (!near &&
          action == 'raise' &&
          exploit.action == 'call' &&
          mixedRaiseOk) {
        near = true;
        trace.add('verdict: raising a completing hand is an acceptable '
            'low-frequency mix — graded CLOSE; the pure play is to complete');
      }
      if (action == 'fold' && ctx.toCallBB <= 0) near = false;
      grade = near ? DrillGrade.ok : DrillGrade.mistake;
      trace.add('verdict math: playability ${play.toStringAsFixed(1)}% vs '
          'range edge ${exploitEdgePct.toStringAsFixed(1)}%'
          '${secondaryEdgePct != null ? ' (raise edge ${secondaryEdgePct.toStringAsFixed(1)}%)' : ''}'
          ' → ${near ? 'within' : 'outside'} ±$_closeBand close band');
    }

    // Varied headline: rotated lead + (opponent read, or a rotated insight
    // when there is no read — kills the repetitive boilerplate).
    final lead = DrillInsights.lead(grade, exploit.action);
    final headlineReason = exploit.fromReads
        ? exploit.reason
        : DrillInsights.insight(ctx, exploit.action, exploit.rangePct, trace);

    var result = DrillGradeResult(
      grade: grade,
      heroAction: action,
      recommendedAction: exploit.action,
      explanation: '$lead $headlineReason',
      handTopPercent: play,
      rangePercent: exploit.rangePct,
      gtoAction: gto.action,
      gtoRangePercent: gto.rangePct,
      gtoReason: gto.reason,
      exploitAction: exploit.action,
      exploitRangePercent: exploit.rangePct,
      exploitReason: exploit.reason,
      trace: trace,
    );

    if (sizingIdealTo != null && sizingLabel != null) {
      result = _withSizingNote(result, action, raiseToBB,
          idealTo: sizingIdealTo, label: sizingLabel, stackBB: ctx.stackBB);
    }
    return result;
  }

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
    if (raiseToBB >= stackBB * 0.9) return result; // jams exempt
    final ratio = raiseToBB / idealTo;
    if (ratio >= 0.7 && ratio <= 1.6) return result;
    final note = ratio < 0.7
        ? 'Size up: a $label around ${idealTo.toStringAsFixed(1)}BB charges the field — ${raiseToBB.toStringAsFixed(1)}BB invites everyone along.'
        : 'That sizing is bigger than needed — around ${idealTo.toStringAsFixed(1)}BB does the same job cheaper.';
    result.trace.add('sizing: to=${raiseToBB.toStringAsFixed(1)}BB vs ideal '
        '${idealTo.toStringAsFixed(1)}BB (ratio ${ratio.toStringAsFixed(2)}) → demoted to CLOSE');
    return result.copyWith(
      grade: DrillGrade.ok,
      explanation: '${result.explanation} $note',
      exploitReason: '${result.exploitReason} $note',
    );
  }

  // ── Small helpers ───────────────────────────────────────────────────

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

}
