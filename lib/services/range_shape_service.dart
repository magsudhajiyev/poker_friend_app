import 'drill_gto_charts.dart';
import 'range_grid_service.dart';

/// RANGE SHAPE analysis (retention doc R11): compares the player's ACTUAL
/// first-in ranges (Range Grid aggregates) against the GTO open charts the
/// app already ships in the drill engine — per position, per 169-cell.
///
/// Where the frequency detectors say HOW OFTEN something is off, this says
/// WITH WHICH HANDS: "on the BTN you keep folding A5s/K9s that the chart
/// opens" (missed opens) and "you open Q5o that the chart folds" (loose
/// opens).
///
/// Honesty guardrails, same spirit as the leak engine:
/// - A position needs [minPositionSpots] RFI spots before it gets a card.
/// - A cell needs [minCellSpots] spots AND a ≥[cellDeviationFreq] rate the
///   wrong way before it is listed — single hands never become findings.
/// - The baseline is the app's ~100BB chart set; everything is presented
///   as DIRECTIONAL ("vs the app's baseline charts"), never as a verdict.
/// - BB is excluded entirely (there is no BB open chart — BB never RFIs).
class ShapeCellDeviation {
  final String handClass;
  final int spots;

  /// Spots that went the "wrong" way: folds for missed opens, opens
  /// (raise+all-in) for loose opens.
  final int offActions;

  const ShapeCellDeviation({
    required this.handClass,
    required this.spots,
    required this.offActions,
  });
}

class PositionShape {
  final String posGroup; // EP/MP/CO/BTN/SB
  final int sampledSpots;
  final double playerOpenFreq; // opens / spots across all sampled cells
  final double chartOpenPct; // combo-weighted chart coverage of all 1326
  final List<ShapeCellDeviation> missedOpens; // chart opens, player folds
  final List<ShapeCellDeviation> looseOpens; // chart folds, player opens

  /// The merged per-cell aggregates behind this analysis — the mini
  /// heatmap renders straight from these.
  final Map<String, RangeCellAggregate> aggregates;

  const PositionShape({
    required this.posGroup,
    required this.sampledSpots,
    required this.playerOpenFreq,
    required this.chartOpenPct,
    required this.missedOpens,
    required this.looseOpens,
    this.aggregates = const {},
  });

  bool get sufficient => sampledSpots >= RangeShapeService.minPositionSpots;
  bool get hasDeviations => missedOpens.isNotEmpty || looseOpens.isNotEmpty;
}

class RangeShapeReport {
  final List<PositionShape> positions; // EP..SB order
  const RangeShapeReport(this.positions);

  List<PositionShape> get sufficient =>
      positions.where((p) => p.sufficient).toList();
  List<PositionShape> get insufficient =>
      positions.where((p) => !p.sufficient).toList();
}

class RangeShapeService {
  RangeShapeService._();

  /// Positions with an RFI chart (BB never opens first-in).
  static const List<String> positions = ['EP', 'MP', 'CO', 'BTN', 'SB'];

  static const int minPositionSpots = 20;
  static const int minCellSpots = 2;
  static const double cellDeviationFreq = 0.67;

  /// Max listed deviations per direction — the worst offenders, by volume.
  static const int maxCells = 8;

  /// Pure per-position comparison — unit-tested without storage.
  static PositionShape analyzePosition({
    required String posGroup,
    required Map<String, RangeCellAggregate> aggregates,
  }) {
    final chart = DrillGtoCharts.openRange(posGroup);

    var spots = 0;
    var opens = 0;
    final missed = <ShapeCellDeviation>[];
    final loose = <ShapeCellDeviation>[];

    for (final agg in aggregates.values) {
      final total = agg.total;
      if (total == 0) continue;
      final cellOpens = agg.raiseCount + agg.allInCount;
      spots += total;
      opens += cellOpens;

      if (total < minCellSpots) continue;
      final inChart = chart.contains(agg.handClass);
      final openFreq = cellOpens / total;
      final foldFreq = agg.foldCount / total;

      if (inChart && foldFreq >= cellDeviationFreq) {
        missed.add(ShapeCellDeviation(
            handClass: agg.handClass,
            spots: total,
            offActions: agg.foldCount));
      } else if (!inChart && openFreq >= cellDeviationFreq) {
        loose.add(ShapeCellDeviation(
            handClass: agg.handClass, spots: total, offActions: cellOpens));
      }
    }

    missed.sort((a, b) => b.offActions.compareTo(a.offActions));
    loose.sort((a, b) => b.offActions.compareTo(a.offActions));

    var chartCombos = 0;
    for (final hc in chart) {
      chartCombos += DrillGtoCharts.combosOf(hc);
    }

    return PositionShape(
      posGroup: posGroup,
      sampledSpots: spots,
      playerOpenFreq: spots == 0 ? 0 : opens / spots,
      chartOpenPct: chartCombos / 1326,
      missedOpens: missed.take(maxCells).toList(),
      looseOpens: loose.take(maxCells).toList(),
      aggregates: aggregates,
    );
  }

  /// Full report: RFI aggregates per position, cash + tournament merged
  /// (the baseline charts are ~100BB; the caption in the UI says so).
  static Future<RangeShapeReport> generate() async {
    final result = <PositionShape>[];
    for (final pos in positions) {
      final merged = <String, RangeCellAggregate>{};
      for (final gameType in const ['cash', 'tournament']) {
        final aggs = await RangeGridService.aggregateByHandClass(
          gameType: gameType,
          posGroup: pos,
          scenario: 'rfi',
        );
        for (final e in aggs.entries) {
          final existing = merged[e.key];
          merged[e.key] = existing == null ? e.value : _merge(existing, e.value);
        }
      }
      result.add(analyzePosition(posGroup: pos, aggregates: merged));
    }
    return RangeShapeReport(result);
  }

  static RangeCellAggregate _merge(
          RangeCellAggregate a, RangeCellAggregate b) =>
      RangeCellAggregate(
        handClass: a.handClass,
        allInCount: a.allInCount + b.allInCount,
        raiseCount: a.raiseCount + b.raiseCount,
        callCount: a.callCount + b.callCount,
        foldCount: a.foldCount + b.foldCount,
        checkCount: a.checkCount + b.checkCount,
      );

  /// Cell paint classification for the mini grid (pure, tested):
  /// 'alignedOpen' | 'missed' | 'loose' | 'alignedFold' | 'noData'.
  static String classifyCell({
    required bool inChart,
    required RangeCellAggregate? agg,
  }) {
    if (agg == null || agg.total < minCellSpots) return 'noData';
    final openFreq = (agg.raiseCount + agg.allInCount) / agg.total;
    final foldFreq = agg.foldCount / agg.total;
    if (inChart) {
      if (foldFreq >= cellDeviationFreq) return 'missed';
      if (openFreq >= 0.5) return 'alignedOpen';
      return 'noData'; // mixed — not enough signal either way
    }
    if (openFreq >= cellDeviationFreq) return 'loose';
    return 'alignedFold';
  }
}
