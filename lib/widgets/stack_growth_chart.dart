import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';
import '../models/hand_state_machine.dart';

/// Default number of data points visible in the viewport.
const _defaultVisiblePoints = 7;

/// Reusable stack growth line chart using fl_chart (matches StackChartScreen style).
/// Shows a fixed window of [visiblePoints] data points. When there are more,
/// the chart scrolls horizontally and defaults to showing the last points.
class StackGrowthChart extends StatefulWidget {
  final List<Map<String, dynamic>> stackHistory;
  final List<HandRecord>? completedHands;
  final double startingStack;
  final String Function(double) formatValue;
  final double height;
  final int? selectedIndex;
  final ValueChanged<int?>? onDotTapped;
  final int visiblePoints;

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
  });

  @override
  State<StackGrowthChart> createState() => _StackGrowthChartState();
}

class _StackGrowthChartState extends State<StackGrowthChart> {
  late double _viewStart;

  @override
  void initState() {
    super.initState();
    _viewStart = _computeDefaultViewStart();
  }

  @override
  void didUpdateWidget(covariant StackGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When new data arrives, keep showing the latest points
    if (widget.stackHistory.length != oldWidget.stackHistory.length) {
      _viewStart = _computeDefaultViewStart();
    }
  }

  double _computeDefaultViewStart() {
    final total = widget.stackHistory.length;
    if (total <= widget.visiblePoints) return -0.5;
    return total - widget.visiblePoints - 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.stackHistory;
    if (data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            l10n.stackChartNoData,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Build spots
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final stackSize = (data[i]['stackSize'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), stackSize));
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    // Compute Y bounds based on visible window for dynamic scaling
    final viewStartIdx = _viewStart.floor().clamp(0, spots.length - 1);
    final viewEndIdx = (_viewStart + (widget.visiblePoints - 1) + 1).ceil().clamp(0, spots.length - 1);
    final visibleSpots = spots.sublist(viewStartIdx, viewEndIdx + 1);
    final rawMinY = visibleSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = visibleSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yPadding = rawMaxY > rawMinY ? (rawMaxY - rawMinY) * 0.15 : rawMaxY * 0.1;
    final minY = rawMinY - yPadding;
    final maxY = rawMaxY + yPadding;
    final yRange = maxY > minY ? maxY - minY : 100.0;
    final yInterval = yRange / 4;

    // Line color based on profit/loss
    final currentStack = spots.last.y;
    final lineColor = currentStack >= widget.startingStack
        ? const Color(0xFF89F1EC)
        : const Color(0xFFFF6B6B);

    // Viewport: show _visiblePoints worth of space
    final viewWindow = (widget.visiblePoints - 1).toDouble() + 1.0; // padding
    final viewMinX = _viewStart;
    final viewMaxX = _viewStart + viewWindow;

    // Total scrollable range
    final totalMaxX = (spots.length - 1).toDouble() + 0.5;
    final scrollMin = -0.5;
    final scrollMax = (totalMaxX - viewWindow).clamp(scrollMin, double.infinity);

    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onHorizontalDragUpdate: spots.length > widget.visiblePoints
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
        child: LineChart(
          LineChartData(
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: yInterval,
                  reservedSize: 50,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      _formatAxisValue(value),
                      style: GoogleFonts.robotoMono(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value != value.roundToDouble()) return const SizedBox.shrink();
                    final idx = value.toInt();
                    if (idx < 0 || idx >= data.length) return const SizedBox.shrink();

                    final entry = data[idx];
                    final changeType = entry['changeType'] ?? 'unknown';
                    String label;
                    switch (changeType) {
                      case 'initial':
                        label = l10n.stackChartStart;
                        break;
                      case 'rebuy':
                        label = l10n.stackChartRebuy;
                        break;
                      case 'final':
                        label = l10n.stackChartEnd;
                        break;
                      default:
                        label = '#${entry['handNumber'] ?? idx}';
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6.0,
                      child: Padding(
                        padding: EdgeInsets.only(left: idx == 0 ? 8 : 0),
                        child: Text(
                          label,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: viewMinX,
            maxX: viewMaxX,
            minY: minY,
            maxY: maxY,
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchSpotThreshold: 40,
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                if (event is FlTapUpEvent && widget.onDotTapped != null) {
                  if (widget.selectedIndex != null) {
                    widget.onDotTapped!(null);
                    return;
                  }
                  if (response != null &&
                      response.lineBarSpots != null &&
                      response.lineBarSpots!.isNotEmpty) {
                    final tappedIndex = response.lineBarSpots!.first.x.toInt();
                    widget.onDotTapped!(tappedIndex);
                  }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1C2926),
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final stackValue = _formatAxisValue(spot.y);

                    if (index >= 0 && index < data.length) {
                      final entry = data[index];
                      final handNumber = entry['handNumber'] as int?;
                      final changeType = entry['changeType'] ?? '';

                      if (changeType != 'initial' &&
                          changeType != 'rebuy' &&
                          changeType != 'final' &&
                          handNumber != null &&
                          handNumber > 0 &&
                          widget.completedHands != null) {
                        HandRecord? hand;
                        if (index > 0 && index <= widget.completedHands!.length) {
                          hand = widget.completedHands![index - 1];
                        }
                        final position = hand?.heroPositionName;
                        final holeCards = hand?.ourHoleCards;
                        final card1 = holeCards?.card1;
                        final card2 = holeCards?.card2;
                        final hasCards = card1 != null && card1.isNotEmpty &&
                            card2 != null && card2.isNotEmpty;

                        String detail = stackValue;
                        if (position != null && position.isNotEmpty) {
                          detail += '  ·  $position';
                        }
                        if (hasCards) {
                          detail += '\n$card1 $card2';
                        }
                        return LineTooltipItem(
                          detail,
                          GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                    }

                    return LineTooltipItem(
                      stackValue,
                      GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            showingTooltipIndicators: widget.selectedIndex != null &&
                    widget.selectedIndex! >= 0 &&
                    widget.selectedIndex! < spots.length
                ? [
                    ShowingTooltipIndicators([
                      LineBarSpot(
                        LineChartBarData(spots: spots),
                        0,
                        spots[widget.selectedIndex!],
                      ),
                    ])
                  ]
                : [],
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                gradient: LinearGradient(
                  colors: [lineColor.withValues(alpha: 0.3), lineColor],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: lineColor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [lineColor.withValues(alpha: 0.15), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
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
    final history = widget.stackHistory;
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
    final prefix = pl >= 0 ? '+' : '';
    if (widget.isCashGame) {
      return '$prefix\$${pl.toStringAsFixed(2)}';
    }
    return '$prefix${pl.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.profitLoss >= 0
        ? const Color(0xFF89F1EC)
        : const Color(0xFFFF6B6B);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF1A4A4A),
              const Color(0xFF161618),
              const Color(0xFF161618),
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
                color: Color(0xFF101115),
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
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.sessionName,
                  style: GoogleFonts.ibmPlexSans(
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
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

