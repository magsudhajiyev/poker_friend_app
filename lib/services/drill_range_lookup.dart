import '../models/drill_models.dart';
import 'drill_gto_charts.dart';
import 'drill_nash_pushfold.dart';

/// Resolves the baseline range chart behind a graded drill decision — the
/// "Show range" button on coach feedback renders exactly the set the grader
/// judged against (same regime selection as DrillGrader: Nash ≤20BB, engine
/// MTT exports in ante mode, curated cash charts otherwise).
///
/// Pure and Flutter-free: layers carry a semantic [DrillRangeLayerKind];
/// the widget maps kinds to colors.
enum DrillRangeLayerKind { raise, call }

class DrillRangeLayer {
  final String label; // 'Open', '3-bet', 'Call', 'Jam', ...
  final DrillRangeLayerKind kind;
  final Set<String> hands; // 169-grid classes

  const DrillRangeLayer({
    required this.label,
    required this.kind,
    required this.hands,
  });
}

class DrillRangeChart {
  final String title; // 'Opening range · BTN'
  final String caption; // provenance line, e.g. 'Nash push/fold @ 15BB'

  /// Painted in order; later layers win on overlap (overlaps shouldn't
  /// happen — chart call sets already exclude their raise sets).
  final List<DrillRangeLayer> layers;

  const DrillRangeChart({
    required this.title,
    required this.caption,
    required this.layers,
  });

  Set<String> get allHands =>
      {for (final l in layers) ...l.hands};
}

class DrillRangeLookup {
  DrillRangeLookup._();

  /// The chart for one graded decision. Never null — every scenario the
  /// engine can produce has a baseline (that's what the grade came from).
  static DrillRangeChart chartFor(DrillDecisionContext ctx) {
    final pos = ctx.positionGroup;
    final profile = DrillGtoCharts.profileFor(ctx.stackBB);

    // ── Nash regime (≤20BB): push/fold tables ─────────────────────────
    if (profile == 'nash') {
      final s = DrillNashPushfold.nearestStack(ctx.stackBB).toInt();
      if (ctx.scenario == DrillScenario.unopened ||
          ctx.scenario == DrillScenario.vsLimpers) {
        return DrillRangeChart(
          title: 'Jamming range · $pos',
          caption: 'Nash push/fold @ ${s}BB'
              '${DrillNashPushfold.isExact(pos) ? '' : ' (approx.)'}',
          layers: [
            DrillRangeLayer(
                label: 'Jam',
                kind: DrillRangeLayerKind.raise,
                hands: DrillNashPushfold.jamRange(pos, ctx.stackBB)),
          ],
        );
      }
      return DrillRangeChart(
        title: 'Calling a jam · $pos',
        caption: 'Nash call vs jam @ ${s}BB',
        layers: [
          DrillRangeLayer(
              label: 'Call',
              kind: DrillRangeLayerKind.call,
              hands: DrillNashPushfold.callVsJamRange(ctx.stackBB)),
        ],
      );
    }

    // ── Deep: scenario-specific charts ─────────────────────────────────
    switch (ctx.scenario) {
      case DrillScenario.unopened:
      case DrillScenario.vsLimpers:
        Set<String> open;
        String caption;
        if (ctx.anteMode) {
          final data = DrillGtoCharts.mttOpenRange(pos, profile);
          if (data != null) {
            open = data.$1;
            caption = 'MTT chart @ $profile';
          } else {
            open = DrillGtoCharts.widen(
                DrillGtoCharts.openRange(pos), DrillGtoCharts.anteWidenPct);
            caption = 'RFI chart + ante widen';
          }
        } else {
          open = DrillGtoCharts.openRange(pos);
          caption = 'RFI chart @ $profile';
        }
        final layers = [
          DrillRangeLayer(
              label: 'Open',
              kind: DrillRangeLayerKind.raise,
              hands: open),
        ];
        // SB with an ante completes most playable hands instead of folding.
        if (ctx.anteMode && pos == 'SB') {
          layers.add(DrillRangeLayer(
              label: 'Complete',
              kind: DrillRangeLayerKind.call,
              hands: DrillGtoCharts.mttSbContinue(profile)
                  .difference(open)));
        }
        return DrillRangeChart(
          title: 'Opening range · $pos',
          caption: caption,
          layers: layers,
        );

      case DrillScenario.vsRaise:
        final opener =
            ctx.openerPosGroup.isEmpty ? 'EP' : ctx.openerPosGroup;
        DefendChart chart;
        String caption;
        if (ctx.anteMode) {
          final mtt = DrillGtoCharts.mttDefendFor(pos, opener, profile);
          if (mtt != null) {
            chart = mtt.$1;
            caption = 'MTT defend vs ${mtt.$2} open @ $profile';
          } else {
            final cash = DrillGtoCharts.defendFor(pos, opener)!;
            chart = cash.$1;
            caption = 'Defend vs ${cash.$2} open';
          }
        } else {
          final cash = DrillGtoCharts.defendFor(pos, opener)!;
          chart = cash.$1;
          caption = 'Defend vs ${cash.$2} open @ $profile';
        }
        return DrillRangeChart(
          title: 'Facing an open · $pos',
          caption: caption,
          layers: [
            DrillRangeLayer(
                label: '3-bet',
                kind: DrillRangeLayerKind.raise,
                hands: chart.threeBet),
            DrillRangeLayer(
                label: 'Call',
                kind: DrillRangeLayerKind.call,
                hands: chart.call),
          ],
        );

      case DrillScenario.vs3betAsAggressor:
        Vs3BetChart chart;
        String caption;
        final mtt = ctx.anteMode
            ? DrillGtoCharts.mttVs3betFor(pos, profile)
            : null;
        if (mtt != null) {
          chart = mtt.$1;
          caption = 'MTT vs 3-bet @ $profile';
        } else {
          chart = DrillGtoCharts.vs3betFor(pos);
          caption = 'Vs 3-bet after a $pos open';
        }
        return DrillRangeChart(
          title: 'Your open got 3-bet · $pos',
          caption: caption,
          layers: [
            DrillRangeLayer(
                label: '4-bet',
                kind: DrillRangeLayerKind.raise,
                hands: chart.fourBet),
            DrillRangeLayer(
                label: 'Call',
                kind: DrillRangeLayerKind.call,
                hands: chart.call),
          ],
        );

      case DrillScenario.vs3betCold:
        return DrillRangeChart(
          title: 'Cold vs 3-bet · $pos',
          caption: 'Uninvested facing two raises — only the top continues',
          layers: [
            DrillRangeLayer(
                label: 'Raise',
                kind: DrillRangeLayerKind.raise,
                hands: DrillGtoCharts.coldVs3betRaise),
            DrillRangeLayer(
                label: 'Continue',
                kind: DrillRangeLayerKind.call,
                hands: DrillGtoCharts.coldVs3betContinue
                    .difference(DrillGtoCharts.coldVs3betRaise)),
          ],
        );
    }
  }
}
