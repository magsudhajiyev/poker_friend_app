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

/// Exploit thresholds keyed by format.
/// Cash = 8-9 max, no antes. MTT = 8-9 max, BB ante.
class _ExploitThresholds {
  final double tightBlindDefend; // Below → "steal relentlessly"
  final double wideBlindDefend; // Above → "drop weakest steals"
  final double tightSteal; // Below → "respect raises"
  final double looseSteal; // Above → "opens loose"
  final double maniacSteal; // Above (+ high aggression) → "maniac"
  final double nitThreeBet; // Below → "only jams premiums"

  const _ExploitThresholds({
    required this.tightBlindDefend,
    required this.wideBlindDefend,
    required this.tightSteal,
    required this.looseSteal,
    required this.maniacSteal,
    required this.nitThreeBet,
  });

  // Passive/station thresholds are the same across formats (postflop behavior)
  static const double passiveAggression = 30;
  static const double stationShowdown = 40;
  static const double limperShowdown = 35;
}

const _cash = _ExploitThresholds(
  tightBlindDefend: 28,
  wideBlindDefend: 50,
  tightSteal: 18,
  looseSteal: 42,
  maniacSteal: 55,
  nitThreeBet: 3.5,
);

const _mtt = _ExploitThresholds(
  tightBlindDefend: 35,
  wideBlindDefend: 60,
  tightSteal: 25,
  looseSteal: 52,
  maniacSteal: 65,
  nitThreeBet: 5,
);

/// Grades hero decisions two ways and shows both:
///
/// 1. **GTO** — chart/table membership, no formulas:
///    - Cash: curated ~100BB charts (RFI, defend-vs-open keyed by BOTH
///      positions, vs-3-bet by opener seat); 20–70BB tightens flat-calls
///      (~40BB transform).
///    - MTT/ante: engine-exported real charts at 100/60/40BB
///      (drill_gto_ranges_data.dart), including the SB complete-or-raise
///      strategy — no widen/tighten heuristics.
///    - ≤20BB (both formats): self-computed Nash push/fold tables (exact
///      for SB-vs-BB, fold-through approximation for earlier seats).
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
    } else if (ctx.anteMode) {
      // Ante format: real MTT charts exported from the engine repo at
      // build time (offline), instead of the old flat +3% widen.
      final data = DrillGtoCharts.mttOpenRange(pos, profile);
      if (data != null) {
        gtoSet = data.$1;
        baseLabel = 'MTT/ante RFI chart $pos @ $profile (${data.$2})';
        trace.add('ante in play: engine MTT chart replaces the cash baseline');
      } else {
        gtoSet = DrillGtoCharts.widen(
            DrillGtoCharts.openRange(pos), DrillGtoCharts.anteWidenPct);
        baseLabel = 'RFI chart $pos @ $profile + ante (fallback)';
        trace.add('ante in play: engine chart missing — curated baseline '
            'widened +${DrillGtoCharts.anteWidenPct.toStringAsFixed(0)}%');
      }
    } else {
      gtoSet = DrillGtoCharts.openRange(pos);
      baseLabel = 'RFI chart $pos @ $profile';
    }
    trace.add('baseline: $baseLabel — '
        '${DrillGtoCharts.coverageOf(gtoSet).toStringAsFixed(1)}% of hands');

    final gtoOpen = gtoSet.contains(ctx.handClass);
    trace.add('gto membership: ${ctx.handClass} '
        '${gtoOpen ? 'IN' : 'NOT IN'} baseline');
    // SB with an ante is NOT raise-or-fold: the dead money makes the small
    // blind complete nearly everything playable instead of folding. The
    // continue set comes from the engine's real SB strategy at this depth
    // (solver folds only ~14–19%), not the old top-75% playability cutoff.
    final sbCompleteSpot = ctx.anteMode && profile != 'nash' && pos == 'SB';
    final sbCompletesHand =
        sbCompleteSpot && DrillGtoCharts.sbCompletesMtt(ctx.handClass, profile);
    final sbCompleteCov = DrillGtoCharts.mttSbContinueCoverage(profile);
    final gtoCompletes = sbCompleteSpot && !gtoOpen && sbCompletesHand;
    if (sbCompleteSpot) {
      trace.add('sb complete strategy: engine continue set = '
          '${sbCompleteCov.toStringAsFixed(1)}% of hands; '
          '${ctx.handClass} ${sbCompletesHand ? 'COMPLETES' : 'FOLDS'} '
          'when not raising');
    }
    // Player-facing reasons stay in plain poker language — the chart
    // provenance ($baseLabel) lives in the trace for debugging.
    final verb = profile == 'nash' ? 'jams' : 'opens';
    final coverShare =
        DrillInsights.naturalShare(DrillGtoCharts.coverageOf(gtoSet));
    final gto = _Line(
      gtoOpen ? 'raise' : (gtoCompletes ? 'call' : 'fold'),
      gtoCompletes ? sbCompleteCov : DrillGtoCharts.coverageOf(gtoSet),
      gtoOpen
          ? '${ctx.handClass} is a standard ${profile == 'nash' ? 'jam' : 'open'} '
              'from ${_posName(pos)} — GTO $verb $coverShare here.'
          : gtoCompletes
              ? '${ctx.handClass} is too weak to raise, but with the ante '
                  'already in the pot the small blind just completes with '
                  'almost everything playable — folding here gives up money.'
              : '${ctx.handClass} is not a GTO ${profile == 'nash' ? 'jam' : 'open'} '
                  'from ${_posName(pos)} — only $coverShare $verb here.',
    );

    // Exploit: widen/tighten along the playability ordering
    final notes = <String>[];
    double widenPct = 0;
    final isStealSeat = pos == 'CO' || pos == 'BTN' || pos == 'SB';

    final blinds =
        ctx.blindsBehind.where((b) => b.profile.isReliable).toList();
    final t = ctx.anteMode ? _mtt : _cash;
    if (isStealSeat && blinds.isNotEmpty) {
      final avgBlindDefend =
          blinds.map((b) => b.profile.blindDefend).reduce((a, b) => a + b) /
              blinds.length;
      final maxThreeBet =
          blinds.map((b) => b.profile.threeBet).reduce((a, b) => a > b ? a : b);
      final names = _nameList(blinds.map((b) => b.profile.name).toList());
      final plural = blinds.length > 1;

      if (avgBlindDefend <= t.tightBlindDefend) {
        final d = ((t.tightBlindDefend - avgBlindDefend) * 1.1)
            .clamp(0.0, 22.0)
            .toDouble();
        widenPct += d;
        trace.add('exploit: tight blinds (avg blind defend '
            '${avgBlindDefend.toStringAsFixed(0)}%) → widen +${d.toStringAsFixed(1)}%');
        notes.add('$names ${plural ? 'defend' : 'defends'} the blinds only '
            '${_pct(avgBlindDefend)} — steal relentlessly from ${_posName(pos)}.');
      } else if (avgBlindDefend >= t.wideBlindDefend) {
        widenPct -= 4;
        trace.add('exploit: wide-defending blinds (avg blind defend '
            '${avgBlindDefend.toStringAsFixed(0)}%) → tighten -4%');
        notes.add('$names ${plural ? 'defend' : 'defends'} wide '
            '(${_pct(avgBlindDefend)}) — drop the weakest steals.');
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
      if (!r.profile.isReliable || r.profile.threeBet < 10 || r.isBlind) {
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
        (p) =>
            p.aggression <= _ExploitThresholds.passiveAggression &&
            p.showdown >= _ExploitThresholds.stationShowdown &&
            p.isReliable,
        (p) => p.showdown);
    if (station != null && aggro == null) {
      widenPct -= 3;
      trace.add('exploit: station behind (aggression ${_pct(station.aggression)}, '
          'showdown ${_pct(station.showdown)}) → tighten -3%');
      notes.add('${station.name} calls down passively '
          '(aggression ${_pct(station.aggression)}, showdown ${_pct(station.showdown)}) '
          '— favour hands that flop well.');
    }

    final exploitSet = widenPct >= 0
        ? DrillGtoCharts.widen(gtoSet, widenPct)
        : DrillGtoCharts.tighten(gtoSet, -widenPct);
    trace.add('exploit range: ${widenPct >= 0 ? '+' : ''}'
        '${widenPct.toStringAsFixed(1)}% → '
        '${DrillGtoCharts.coverageOf(exploitSet).toStringAsFixed(1)}% of hands; '
        '${ctx.handClass} ${exploitSet.contains(ctx.handClass) ? 'IN' : 'NOT IN'}');
    final exploitOpen = exploitSet.contains(ctx.handClass);
    final exploitCompletes = sbCompleteSpot && !exploitOpen && sbCompletesHand;
    final exploitReason = notes.isEmpty
        ? 'No exploitable reads behind you — the exploit matches the GTO baseline.'
        : notes.join(' ');
    final exploit = _Line(
        exploitOpen ? 'raise' : (exploitCompletes ? 'call' : 'fold'),
        exploitCompletes ? sbCompleteCov : DrillGtoCharts.coverageOf(exploitSet),
        exploitReason,
        fromReads: notes.isNotEmpty);

    // Folding a hand the engine SB strategy NEVER folds is a real mistake
    // even right at the range edge; folds the solver genuinely mixes
    // (sbFoldMix) keep the usual close-band tolerance.
    final strictFold = exploitCompletes &&
        !DrillGtoCharts.mttSbFoldMix(profile).contains(ctx.handClass);

    return _finalize(ctx, action, raiseToBB,
        gto: gto,
        exploit: exploit,
        exploitEdgePct: exploitCompletes
            ? sbCompleteCov
            : DrillGtoCharts.coverageOf(exploitSet),
        secondaryEdgePct:
            exploitCompletes ? DrillGtoCharts.coverageOf(exploitSet) : null,
        mixedRaiseOk: exploitCompletes,
        strictFold: strictFold,
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
        'Iso-raise ${DrillInsights.naturalShare(DrillGtoCharts.coverageOf(isoBase))} '
        'over $limperCount limper${plural ? 's' : ''}; take free flops with the rest.');

    // Exploit
    final notes = <String>[];
    var isoSet = isoBase;
    final loosePassive = _strongest(
        ctx.limpers,
        (p) =>
            p.aggression <= _ExploitThresholds.passiveAggression &&
            p.showdown >= _ExploitThresholds.limperShowdown &&
            p.isReliable,
        (p) => p.showdown);
    if (loosePassive != null) {
      isoSet = DrillGtoCharts.widen(isoSet, 4);
      trace.add('exploit: loose-passive limper '
          '(aggression ${_pct(loosePassive.aggression)}) → widen iso +4%');
      notes.add('${loosePassive.name} limps and calls passively '
          '(aggression ${_pct(loosePassive.aggression)}, '
          '${loosePassive.confidenceLabel}) — isolate wide and take the lead.');
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
      final tj = ctx.anteMode ? _mtt : _cash;
      if (o != null && o.isReliable) {
        if ((o.steal >= tj.maniacSteal && o.aggression >= 60) ||
            o.archetype == 'Maniac') {
          callSetX = DrillGtoCharts.widen(callSet, 5);
          trace.add('exploit: maniac jammer (steal ${_pct(o.steal)}, '
              'aggression ${_pct(o.aggression)}) → call +5%');
          notes.add('${o.name} shoves wide (${o.confidenceLabel}) — call lighter.');
        } else if (o.steal <= tj.tightSteal && o.threeBet <= tj.nitThreeBet) {
          callSetX = DrillGtoCharts.tighten(callSet, 4);
          trace.add('exploit: nit jammer (steal ${_pct(o.steal)}, '
              '3-bet ${_pct(o.threeBet)}) → call -4%');
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

    // Chart defend, keyed by BOTH positions. Ante format uses the real
    // engine charts at this depth; cash keeps the curated charts (with the
    // 40bb tightening transform below 100bb).
    DefendChart chart;
    String usedOpener;
    String chartSource;
    final mtt = ctx.anteMode && profile != 'nash'
        ? DrillGtoCharts.mttDefendFor(pos, openerPos, profile)
        : null;
    if (mtt != null) {
      chart = mtt.$1;
      usedOpener = mtt.$2;
      chartSource = mtt.$3;
    } else {
      final resolved = DrillGtoCharts.defendFor(pos, openerPos);
      chart = resolved?.$1 ??
          DefendChart(
              threeBet:
                  DrillGtoCharts.tighten(DrillGtoCharts.openRange(pos), 30),
              call: <String>{});
      usedOpener = resolved?.$2 ?? openerPos;
      if (profile != '100bb') {
        chart = DrillGtoCharts.defendAt40bb(chart);
      }
      chartSource = 'curated';
    }
    if (ctx.heroLimped) {
      trace.add('note: hero LIMPED earlier — grading with the cold-defend '
          'chart (limp-defend ranges are an approximation here)');
    }
    trace.add('baseline: defend chart $pos vs $usedOpener open @ $profile '
        '($chartSource) — '
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
    final tv = ctx.anteMode ? _mtt : _cash;
    if (o != null && o.isReliable) {
      if (o.fold3bet >= 60) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 6);
        trace.add('exploit: opener folds to 3-bets ${_pct(o.fold3bet)} → 3bet +6%');
        notes.add('${o.name} folds to 3-bets ${_pct(o.fold3bet)} '
            '(${o.confidenceLabel}) — 3-bet him relentlessly.');
      }
      if (o.steal >= tv.looseSteal) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 4);
        callSet = DrillGtoCharts.widen(callSet, 4);
        trace.add('exploit: loose opener (steal ${_pct(o.steal)}) → 3bet +4%, call +4%');
        notes.add('${o.name} opens loose (steal ${_pct(o.steal)}) — widen value.');
      } else if (o.steal <= tv.tightSteal + 4 && o.threeBet <= tv.nitThreeBet) {
        threeBetSet = DrillGtoCharts.tighten(threeBetSet, 2);
        callSet = DrillGtoCharts.tighten(callSet, 5);
        trace.add('exploit: nitty opener (steal ${_pct(o.steal)}) → 3bet -2%, call -5%');
        notes.add('${o.name} raises very tight (steal ${_pct(o.steal)}) — '
            'respect his raises.');
      }
      if (o.archetype == 'Maniac' ||
          (o.steal >= tv.maniacSteal && o.aggression >= 60)) {
        threeBetSet = DrillGtoCharts.widen(threeBetSet, 5);
        callSet = DrillGtoCharts.widen(callSet, 5);
        trace.add('exploit: maniac opener (steal ${_pct(o.steal)}, '
            'aggression ${_pct(o.aggression)}) → 3bet +5%, call +5%');
        notes.add('${o.name} raises aggressively (steal ${_pct(o.steal)}, '
            'aggression ${_pct(o.aggression)}) — play back wider.');
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
    var chartSource = 'curated';
    Vs3BetChart chart;
    final mtt = ctx.anteMode && profile != 'nash'
        ? DrillGtoCharts.mttVs3betFor(pos, profile)
        : null;
    if (mtt != null) {
      chart = mtt.$1;
      chartSource = mtt.$2;
    } else {
      chart = DrillGtoCharts.vs3betFor(pos);
      if (profile != '100bb') {
        chart = Vs3BetChart(
          fourBet: chart.fourBet,
          call: profile == 'nash'
              ? <String>{} // jam-or-fold: flats disappear
              : DrillGtoCharts.tighten(
                  chart.call, DrillGtoCharts.coverageOf(chart.call) * 0.35),
        );
      }
    }
    trace.add('baseline: vs-3bet chart (opened from $pos) @ $profile '
        '($chartSource) — '
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
    if (tb != null && tb.isReliable) {
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
    final tc = ctx.anteMode ? _mtt : _cash;
    if (ctx.opener != null &&
        ctx.opener!.isReliable &&
        ctx.opener!.steal >= tc.looseSteal) {
      cont = DrillGtoCharts.widen(cont, 2);
      trace.add('exploit: loose aggressors (steal ${_pct(ctx.opener!.steal)}) → continue +2%');
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
    bool strictFold = false,
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
      if (action == 'fold' && strictFold) {
        near = false;
        trace.add('verdict: the engine strategy never folds this hand here '
            '— fold graded a full mistake despite range-edge proximity');
      }
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
