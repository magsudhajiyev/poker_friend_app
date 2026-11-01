import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/components/chart_reveal_clip.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';
import '../services/currency_service.dart';
import '../services/stack_timeline.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Default number of data points visible in the viewport.
const _defaultVisiblePoints = 7;

/// Reserved axis sizes (also used to place the pending label chip).
const _leftAxisWidth = 50.0;
const _bottomAxisHeight = 24.0;

/// What the tooltip shows about a hand.
class ChartHandInfo {
  final String? position;
  final String? card1;
  final String? card2;

  const ChartHandInfo({this.position, this.card1, this.card2});

  bool get hasCards =>
      card1 != null && card1!.isNotEmpty && card2 != null && card2!.isNotEmpty;
}

typedef ChartHandLookup = ChartHandInfo? Function(int handNumber);

/// Lookup over [HandRecord]s by their hand NUMBER (not list position: fold
/// ticks and flags consume numbers, so number-1 is not an index).
ChartHandLookup handLookupFromRecords(List<HandRecord>? hands) {
  return (n) {
    if (hands == null) return null;
    for (final h in hands) {
      if (h.handNumber != n) continue;
      return ChartHandInfo(
        position: h.heroPositionName,
        card1: h.ourHoleCards?.card1,
        card2: h.ourHoleCards?.card2,
      );
    }
    return null;
  };
}

/// Lookup over raw hand maps (Firestore docs) by their `handNumber`.
ChartHandLookup handLookupFromMaps(List<Map<String, dynamic>> hands) {
  return (n) {
    for (final h in hands) {
      if (h['handNumber'] != n) continue;
      final cards = h['ourHoleCards'];
      return ChartHandInfo(
        position: h['heroPositionName'] as String?,
        card1: cards is Map ? cards['card1'] as String? : null,
        card2: cards is Map ? cards['card2'] as String? : null,
      );
    }
    return null;
  };
}

/// Tries [primary] first, then [fallback] (e.g. promoted-stub docs that are
/// not in the live manager's completed list). A primary hit without cards or
/// position is completed from the fallback.
ChartHandLookup handLookupChain(ChartHandLookup primary, ChartHandLookup fallback) {
  return (n) {
    final a = primary(n);
    if (a != null && a.hasCards && (a.position ?? '').isNotEmpty) return a;
    final b = fallback(n);
    if (a == null) return b;
    if (b == null) return a;
    return ChartHandInfo(
      position: (a.position ?? '').isNotEmpty ? a.position : b.position,
      card1: a.hasCards ? a.card1 : b.card1,
      card2: a.hasCards ? a.card2 : b.card2,
    );
  };
}

/// The one stack growth line chart (session details card, full screen, and
/// session analytics all render this).
///
/// Shows a fixed window of [visiblePoints] data points. When there are more,
/// the chart scrolls horizontally and defaults to showing the last points.
/// The plotted series comes from [StackTimeline.build]: sessions without
/// easy-logging data render exactly as the plain index-based line.
class StackGrowthChart extends StatefulWidget {
  final List<Map<String, dynamic>> stackHistory;
  final List<HandRecord>? completedHands;
  final double startingStack;
  final String Function(double) formatValue;
  final double height;

  /// Index into the plotted points of the open tooltip.
  final int? selectedIndex;
  final ValueChanged<int?>? onDotTapped;
  final int visiblePoints;

  /// Flag results by flag id (see [FlagResolution]).
  final Map<String, FlagResolution> resolutions;

  /// Hand info by hand number. Defaults to a lookup over [completedHands].
  final ChartHandLookup? handLookup;

  /// Called with the flag ids when a pending dot or its label is tapped.
  final ValueChanged<List<String>>? onPendingTapped;

  /// When set, tapping an open tooltip opens that hand instead of closing it.
  final ValueChanged<int>? onHandOpen;

  /// Tournament big-blind view: each point uses its own blind.
  final bool showBigBlinds;
  final double? Function(int handNumber)? bigBlindForHand;

  /// Blind used when no point knows its own (see [StackTimelineData.inBigBlinds]).
  final double? fallbackBigBlind;

  const StackGrowthChart({
    super.key,
    required this.stackHistory,
    this.completedHands,
    required this.startingStack,
    required this.formatValue,
    this.height = 200,
    this.selectedIndex,
    this.onDotTapped,
    this.visiblePoints = _defaultVisiblePoints,
    this.resolutions = const {},
    this.handLookup,
    this.onPendingTapped,
    this.onHandOpen,
    this.showBigBlinds = false,
    this.bigBlindForHand,
    this.fallbackBigBlind,
  });

  @override
  State<StackGrowthChart> createState() => _StackGrowthChartState();
}

class _StackGrowthChartState extends State<StackGrowthChart> {
  late double _viewStart;

  StackTimelineData _timeline(StackGrowthChart w) {
    final t = StackTimeline.build(w.stackHistory, w.resolutions);
    final bb = w.bigBlindForHand;
    return w.showBigBlinds && bb != null ? t.inBigBlinds(bb, fallback: w.fallbackBigBlind) : t;
  }

  int _slots(StackTimelineData t) {
    var max = -1;
    for (final p in t.points) {
      if (p.x > max) max = p.x.toInt();
    }
    return max + 1;
  }

  @override
  void initState() {
    super.initState();
    _viewStart = _computeDefaultViewStart(_slots(_timeline(widget)));
  }

  @override
  void didUpdateWidget(covariant StackGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When new data arrives, keep showing the latest points
    final now = _slots(_timeline(widget));
    if (now != _slots(_timeline(oldWidget))) {
      _viewStart = _computeDefaultViewStart(now);
    }
  }

  double _computeDefaultViewStart(int total) {
    if (total <= widget.visiblePoints) return -0.5;
    return total - widget.visiblePoints - 0.5;
  }

  ChartHandInfo? _hand(int n) {
    final lookup = widget.handLookup ?? handLookupFromRecords(widget.completedHands);
    return lookup(n);
  }

  String _fmt(double value) {
    if (widget.showBigBlinds) {
      return '${value.toStringAsFixed(value.abs() >= 100 ? 0 : 1)} BB';
    }
    return _formatAxisValue(value);
  }

  /// Easy-logging data present (fold runs, flags, rebuy before-stack).
  bool get _hasEasyKinds => widget.stackHistory.any((e) =>
      e['changeType'] == 'fold_run' ||
      e['changeType'] == 'pending' ||
      e['stackBefore'] != null);

  bool _showsHandInfo(TimelinePoint p) {
    final t = p.changeType;
    return t == 'win' || t == 'loss' || t == 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.stackHistory.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            l10n.stackChartNoData,
            style: AppTypography.ibm(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final timeline = _timeline(widget);
    final points = timeline.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final slots = _slots(timeline);

    // Compute Y bounds based on visible window for dynamic scaling
    final lo = _viewStart.floor().clamp(0, slots - 1);
    final hi = (_viewStart + (widget.visiblePoints - 1) + 1).ceil().clamp(0, slots - 1);
    var visible = points.where((p) => p.x >= lo && p.x <= hi).toList();
    if (visible.isEmpty) visible = points;
    final rawMinY = visible.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = visible.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yPadding = rawMaxY > rawMinY ? (rawMaxY - rawMinY) * 0.15 : rawMaxY * 0.1;
    final minY = rawMinY - yPadding;
    final maxY = rawMaxY + yPadding;
    final yRange = maxY > minY ? maxY - minY : 100.0;
    final yInterval = yRange / 4;

    // Line color based on profit/loss
    final currentStack = points.last.y;
    final start = widget.showBigBlinds ? points.first.y : widget.startingStack;
    final lineColor = currentStack >= start
        ? AppColors.accentPrimary
        : const Color(0xFFFF6B6B);

    // Viewport: show _visiblePoints worth of space
    final viewWindow = (widget.visiblePoints - 1).toDouble() + 1.0; // padding
    final viewMinX = _viewStart;
    final viewMaxX = _viewStart + viewWindow;

    // Total scrollable range
    final totalMaxX = (slots - 1).toDouble() + 0.5;
    const scrollMin = -0.5;
    final scrollMax = (totalMaxX - viewWindow).clamp(scrollMin, double.infinity);

    final sel = widget.selectedIndex;
    final selPoint = sel != null && sel >= 0 && sel < points.length ? points[sel] : null;
    // Check if selected entry has a long note that needs scrollable overlay
    final bool showNoteOverlay = selPoint?.entry != null && _hasLongNote(selPoint!.entry!);

    final bars = _bars(timeline, lineColor);
    final bySlot = {
      for (final p in points)
        if (p.kind != TimelinePointKind.rebuyStep) p.x.toInt(): p,
    };

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onHorizontalDragUpdate: slots > widget.visiblePoints
                  ? (details) {
                      // Convert drag pixels to chart units
                      final chartWidth = context.size?.width ?? 300;
                      final unitsPerPixel = viewWindow / chartWidth;
                      final delta = -details.delta.dx * unitsPerPixel;
                      setState(() {
                        _viewStart = (_viewStart + delta).clamp(scrollMin, scrollMax);
                        // Dismiss tooltip on scroll
                        if (widget.onDotTapped != null && widget.selectedIndex != null) {
                          widget.onDotTapped!(null);
                        }
                      });
                    }
                  : null,
              child: ChartRevealClip(
                child: LineChart(
                  LineChartData(
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: _titles(l10n, bySlot, yInterval, _hasEasyKinds),
                    borderData: FlBorderData(show: false),
                    minX: viewMinX,
                    maxX: viewMaxX,
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: _touch(timeline),
                    showingTooltipIndicators: _indicators(timeline, bars, showNoteOverlay),
                    lineBarsData: bars,
                  ),
                ),
              ),
            ),
            ..._labelChips(
              l10n,
              timeline,
              box,
              viewMinX: viewMinX,
              viewMaxX: viewMaxX,
              minY: minY,
              maxY: maxY,
              color: lineColor,
            ),
            // Scrollable note overlay
            if (showNoteOverlay)
              Positioned(
                top: 4,
                left: 16,
                right: 16,
                child: _buildNoteOverlay(selPoint),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bars ────────────────────────────────────────────────────────────────

  List<LineChartBarData> _bars(StackTimelineData t, Color lineColor) {
    return [
      for (final seg in t.segments)
        _bar(t.points.sublist(seg.start, seg.end + 1), seg, lineColor),
    ];
  }

  LineChartBarData _bar(List<TimelinePoint> pts, TimelineSegment seg, Color lineColor) {
    final hasStep = pts.any((p) => p.kind == TimelinePointKind.rebuyStep);
    return LineChartBarData(
      spots: [for (final p in pts) FlSpot(p.x, p.y)],
      isCurved: !seg.dashed && !hasStep,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      gradient: seg.dashed
          ? LinearGradient(colors: [lineColor.withValues(alpha: 0.7), lineColor.withValues(alpha: 0.7)])
          : LinearGradient(colors: [lineColor.withValues(alpha: 0.3), lineColor]),
      barWidth: 3,
      isStrokeCapRound: true,
      dashArray: seg.dashed ? const [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) =>
            _dot(pts[index.clamp(0, pts.length - 1)], lineColor),
      ),
      belowBarData: BarAreaData(
        show: !seg.dashed,
        gradient: LinearGradient(
          colors: [lineColor.withValues(alpha: 0.15), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  FlDotPainter _dot(TimelinePoint p, Color lineColor) {
    switch (p.kind) {
      case TimelinePointKind.rebuyStep:
        return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
      case TimelinePointKind.pending:
      case TimelinePointKind.unlogged:
        // Hollow: the value is not confirmed.
        return FlDotCirclePainter(
          radius: 4,
          color: AppColors.bgSurface,
          strokeWidth: 2,
          strokeColor: lineColor,
        );
      case TimelinePointKind.real:
        return FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: lineColor,
        );
    }
  }

  // ── Titles ──────────────────────────────────────────────────────────────

  FlTitlesData _titles(
    AppLocalizations l10n,
    Map<int, TimelinePoint> bySlot,
    double yInterval,
    bool easyKinds,
  ) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: yInterval,
          reservedSize: _leftAxisWidth,
          getTitlesWidget: (double value, TitleMeta meta) => Text(
            _formatAxisValue(value),
            style: AppTypography.mono(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _bottomAxisHeight,
          interval: 1,
          getTitlesWidget: (double value, TitleMeta meta) {
            if (value != value.roundToDouble()) return const SizedBox.shrink();
            final idx = value.toInt();
            final point = bySlot[idx];
            if (point == null) return const SizedBox.shrink();
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 6.0,
              child: Padding(
                padding: EdgeInsets.only(left: idx == 0 ? 8 : 0),
                child: Text(
                  _axisLabel(l10n, point, idx, easyKinds),
                  style: AppTypography.ibm(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _axisLabel(AppLocalizations l10n, TimelinePoint p, int idx, bool easyKinds) {
    if (p.kind == TimelinePointKind.unlogged) return '';
    switch (p.changeType) {
      case 'initial':
        return l10n.stackChartStart;
      case 'rebuy':
        return l10n.stackChartRebuy;
      case 'final':
        return l10n.stackChartEnd;
      case 'manual_increase':
      case 'manual_decrease':
        // Older sessions keep the plain hand label.
        if (!easyKinds) return '#${p.handNumber ?? idx}';
        return '📝';
      default:
        return '#${p.handNumber ?? idx}';
    }
  }

  // ── Touch ───────────────────────────────────────────────────────────────

  int? _pointIndexOf(StackTimelineData t, LineTouchResponse? r) {
    final spots = r?.lineBarSpots;
    if (spots == null || spots.isEmpty) return null;
    final s = spots.first;
    if (s.barIndex < 0 || s.barIndex >= t.segments.length) return null;
    return t.segments[s.barIndex].start + s.spotIndex;
  }

  LineTouchData _touch(StackTimelineData t) {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: false,
      touchSpotThreshold: 40,
      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
        if (event is FlTapUpEvent) _onTap(t, _pointIndexOf(t, response));
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF1C2926),
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) =>
            [for (final s in touchedSpots) _tooltipItem(t, s)],
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        maxContentWidth: 200,
      ),
    );
  }

  void _onTap(StackTimelineData t, int? tapped) {
    final cb = widget.onDotTapped;
    if (cb == null) return;
    final point = tapped != null ? t.points[tapped] : null;
    final open = widget.onPendingTapped;
    if (point != null && point.kind == TimelinePointKind.pending && open != null && point.flagIds.isNotEmpty) {
      cb(null);
      open(point.flagIds);
      return;
    }
    final sel = widget.selectedIndex;
    if (sel == null) {
      if (tapped != null) cb(tapped);
      return;
    }
    if (widget.onHandOpen != null && tapped != null && tapped != sel) {
      cb(tapped);
      return;
    }
    cb(null);
    _openHand(t, sel);
  }

  void _openHand(StackTimelineData t, int index) {
    final open = widget.onHandOpen;
    if (open == null || index < 0 || index >= t.points.length) return;
    final p = t.points[index];
    final n = p.handNumber;
    if (n != null && n > 0 && _showsHandInfo(p) && p.kind == TimelinePointKind.real) {
      open(n);
    }
  }

  LineTooltipItem _tooltipItem(StackTimelineData t, LineBarSpot spot) {
    final index = t.segments[spot.barIndex].start + spot.spotIndex;
    final style = AppTypography.ibm(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    if (index < 0 || index >= t.points.length) {
      return LineTooltipItem(_fmt(spot.y), style);
    }
    return LineTooltipItem(_tooltipText(t.points[index]), style);
  }

  String _tooltipText(TimelinePoint p) {
    final l10n = AppLocalizations.of(context);
    var detail = _fmt(p.y);
    if (p.kind == TimelinePointKind.pending) {
      return '$detail\n${l10n.stackChartPendingTooltip(p.handNumber ?? 0)}';
    }
    if (p.kind == TimelinePointKind.unlogged) {
      return '$detail\n${l10n.stackChartUnlogged(_signed(p.gap ?? 0))}';
    }
    final handNumber = p.handNumber;
    if (_showsHandInfo(p) && handNumber != null && handNumber > 0) {
      final hand = _hand(handNumber);
      final position = hand?.position;
      if (position != null && position.isNotEmpty) detail += '  ·  $position';
      if (hand != null && hand.hasCards) detail += '\n${hand.card1} ${hand.card2}';
    }
    final note = p.entry?['note'] as String?;
    if (note != null && note.isNotEmpty) detail += '\n📝 $note';
    return detail;
  }

  List<ShowingTooltipIndicators> _indicators(
    StackTimelineData t,
    List<LineChartBarData> bars,
    bool showNoteOverlay,
  ) {
    final i = widget.selectedIndex;
    if (i == null || i < 0 || i >= t.points.length || showNoteOverlay) return const [];
    final barIdx = t.segments.indexWhere((s) => i >= s.start && i <= s.end);
    if (barIdx < 0) return const [];
    final p = t.points[i];
    return [
      ShowingTooltipIndicators([
        LineBarSpot(bars[barIdx], barIdx, FlSpot(p.x, p.y)),
      ])
    ];
  }

  // ── Label chips on dashed bars ──────────────────────────────────────────

  String _signed(double v) =>
      '${v >= 0 ? '+' : '-'}${widget.formatValue(v.abs())}';

  List<Widget> _labelChips(
    AppLocalizations l10n,
    StackTimelineData t,
    BoxConstraints box, {
    required double viewMinX,
    required double viewMaxX,
    required double minY,
    required double maxY,
    required Color color,
  }) {
    final w = box.maxWidth;
    final h = box.maxHeight.isFinite ? box.maxHeight : widget.height;
    if (!w.isFinite || !h.isFinite) return const [];
    final plotW = w - _leftAxisWidth;
    final plotH = h - _bottomAxisHeight;
    final out = <Widget>[];
    for (final seg in t.segments) {
      if (!seg.dashed) continue;
      final a = t.points[seg.start];
      final b = t.points[seg.end];
      final mx = (a.x + b.x) / 2;
      if (mx < viewMinX || mx > viewMaxX) continue;
      final label = seg.pendingCount > 0
          ? l10n.stackChartHandsPending(seg.pendingCount)
          : seg.unloggedGap != null
              ? l10n.stackChartUnlogged(_signed(seg.unloggedGap!))
              : null;
      if (label == null) continue;
      final cx = _leftAxisWidth + (mx - viewMinX) / (viewMaxX - viewMinX) * plotW;
      final my = (a.y + b.y) / 2;
      final cy = (maxY - my) / (maxY - minY) * plotH;
      out.add(Positioned(
        left: cx - 70,
        width: 140,
        top: (cy - 34).clamp(0.0, plotH),
        child: Center(
          child: _chip(label, color,
              seg.pendingCount > 0 && widget.onPendingTapped != null
                  ? () => widget.onPendingTapped!(seg.flagIds)
                  : null),
        ),
      ));
    }
    return out;
  }

  Widget _chip(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDecorations.radius20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _hasLongNote(Map<String, dynamic> entry) {
    final note = entry['note'] as String?;
    return note != null && note.length > 30;
  }

  Widget _buildNoteOverlay(TimelinePoint point) {
    final entry = point.entry!;
    final note = entry['note'] as String? ?? '';
    final handNumber = point.handNumber;

    String header = _fmt(point.y);

    // Hand info
    if (_showsHandInfo(point) && handNumber != null && handNumber > 0) {
      final hand = _hand(handNumber);
      final position = hand?.position;
      if (position != null && position.isNotEmpty) {
        header += '  ·  $position';
      }
      if (hand != null && hand.hasCards) {
        header += '  ·  ${hand.card1} ${hand.card2}';
      }
    }

    return GestureDetector(
      onTap: () {
        if (widget.onDotTapped != null) widget.onDotTapped!(null);
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 120),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2926),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                header,
                style: AppTypography.ibm(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                style: AppTypography.ibm(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAxisValue(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }
}

/// Fullscreen landscape chart screen — matches StackChartScreen design.
class StackGrowthChartFullScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stackHistory;
  final List<HandRecord>? completedHands;
  final double startingStack;
  final String Function(double) formatValue;
  final double profitLoss;
  final String sessionName;
  final Duration sessionDuration;
  final bool isCashGame;
  final Map<String, FlagResolution> resolutions;
  final ChartHandLookup? handLookup;
  final ValueChanged<List<String>>? onPendingTapped;
  final bool showBigBlinds;
  final double? Function(int handNumber)? bigBlindForHand;
  final double? fallbackBigBlind;

  const StackGrowthChartFullScreen({
    super.key,
    required this.stackHistory,
    this.completedHands,
    required this.startingStack,
    required this.formatValue,
    required this.profitLoss,
    required this.sessionName,
    required this.sessionDuration,
    required this.isCashGame,
    this.resolutions = const {},
    this.handLookup,
    this.onPendingTapped,
    this.showBigBlinds = false,
    this.bigBlindForHand,
    this.fallbackBigBlind,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> stackHistory,
    List<HandRecord>? completedHands,
    required double startingStack,
    required String Function(double) formatValue,
    required double profitLoss,
    required String sessionName,
    required Duration sessionDuration,
    required bool isCashGame,
    Map<String, FlagResolution> resolutions = const {},
    ChartHandLookup? handLookup,
    ValueChanged<List<String>>? onPendingTapped,
    bool showBigBlinds = false,
    double? Function(int handNumber)? bigBlindForHand,
    double? fallbackBigBlind,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StackGrowthChartFullScreen(
          stackHistory: stackHistory,
          completedHands: completedHands,
          startingStack: startingStack,
          formatValue: formatValue,
          profitLoss: profitLoss,
          sessionName: sessionName,
          sessionDuration: sessionDuration,
          isCashGame: isCashGame,
          resolutions: resolutions,
          handLookup: handLookup,
          onPendingTapped: onPendingTapped,
          showBigBlinds: showBigBlinds,
          bigBlindForHand: bigBlindForHand,
          fallbackBigBlind: fallbackBigBlind,
        ),
      ),
    );
  }

  @override
  State<StackGrowthChartFullScreen> createState() =>
      _StackGrowthChartFullScreenState();
}

class _StackGrowthChartFullScreenState
    extends State<StackGrowthChartFullScreen> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration() {
    final hours = widget.sessionDuration.inHours;
    final minutes = widget.sessionDuration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _formatAvgGrowth() {
    final history = widget.stackHistory
        .where((e) => e['changeType'] != 'fold_run' && e['changeType'] != 'pending')
        .toList();
    if (history.length < 2) return AppLocalizations.of(context).commonNotAvailable;

    int handCount = 0;
    double totalGrowth = 0.0;
    for (int i = 1; i < history.length; i++) {
      final current = (history[i]['stackSize'] as num?)?.toDouble() ?? 0.0;
      final previous = (history[i - 1]['stackSize'] as num?)?.toDouble() ?? 0.0;
      if (previous > 0) {
        totalGrowth += ((current - previous) / previous) * 100;
        handCount++;
      }
    }
    if (handCount == 0) return AppLocalizations.of(context).commonNotAvailable;
    final avg = totalGrowth / handCount;
    return '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(2)}%';
  }

  String _formatPL() {
    final pl = widget.profitLoss;
    final sign = pl >= 0 ? '+' : '-';
    if (widget.isCashGame) {
      return '$sign${CurrencyService.formatCash(pl.abs())}';
    }
    return '${pl >= 0 ? '+' : ''}${pl.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.profitLoss >= 0
        ? AppColors.accentPrimary
        : const Color(0xFFFF6B6B);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF1A4A4A),
              AppColors.surfaceVariant1,
              AppColors.surfaceVariant1,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(lineColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: StackGrowthChart(
                    stackHistory: widget.stackHistory,
                    completedHands: widget.completedHands,
                    startingStack: widget.startingStack,
                    formatValue: widget.formatValue,
                    height: double.infinity,
                    visiblePoints: 20,
                    resolutions: widget.resolutions,
                    handLookup: widget.handLookup,
                    onPendingTapped: widget.onPendingTapped,
                    showBigBlinds: widget.showBigBlinds,
                    bigBlindForHand: widget.bigBlindForHand,
                    fallbackBigBlind: widget.fallbackBigBlind,
                    selectedIndex: _selectedIndex,
                    onDotTapped: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color lineColor) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.stackChartTitle,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.sessionName,
                  style: AppTypography.ibm(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Info pills
          _buildInfoPill(l10n.stackChartAvgGrowth, _formatAvgGrowth(), lineColor),
          const SizedBox(width: 10),
          _buildInfoPill(l10n.stackChartDuration, _formatDuration(), Colors.white),
          const SizedBox(width: 10),
          _buildInfoPill(
            widget.isCashGame ? l10n.stackChartProfitLoss : l10n.stackChartScreenStack,
            widget.isCashGame
                ? _formatPL()
                : widget.formatValue(
                    widget.stackHistory.isNotEmpty
                        ? (widget.stackHistory.last['stackSize'] as num?)
                                ?.toDouble() ??
                            0.0
                        : 0.0,
                  ),
            lineColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDecorations.radius20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: AppTypography.ibm(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 12,
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

