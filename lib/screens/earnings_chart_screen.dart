import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/components/chart_reveal_clip.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../l10n/app_localizations.dart';
import '../services/session_result_service.dart';
import '../design_system/constants/colors.dart';
import '../services/currency_service.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Full-screen landscape earnings chart with zoom/pan
/// Shows all-time cumulative earnings for tournament and cash games
class EarningsChartScreen extends StatefulWidget {
  const EarningsChartScreen({super.key});

  @override
  State<EarningsChartScreen> createState() => _EarningsChartScreenState();
}

class _EarningsChartScreenState extends State<EarningsChartScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chartData = [];
  double _tournamentTotal = 0.0;
  double _cashTotal = 0.0;
  DateTime? _firstSessionDate;

  // Viewport scrolling
  late double _viewStart;
  static const int _visiblePoints = 15;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _loadAllTimeEarningsData();
  }

  @override
  void dispose() {
    _restorePortraitMode();
    super.dispose();
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _loadAllTimeEarningsData() async {
    try {
      final sessionResults = await SessionResultService.getAllSessionResults();

      if (sessionResults.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Group by date and calculate daily totals
      Map<DateTime, Map<String, double>> dailyData = {};

      for (var result in sessionResults) {
        DateTime? date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.tryParse(result['createdAt']);
        }

        if (date == null) continue;

        final dateKey = DateTime(date.year, date.month, date.day);
        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        dailyData.putIfAbsent(dateKey, () => {'tournament': 0.0, 'cash': 0.0});
        dailyData[dateKey]![gameType] =
            (dailyData[dateKey]![gameType] ?? 0.0) + amount;
      }

      final sortedDates = dailyData.keys.toList()..sort();

      if (sortedDates.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Calculate cumulative totals
      double cumulativeTournament = 0.0;
      double cumulativeCash = 0.0;

      List<Map<String, dynamic>> chartData = sortedDates.map((date) {
        cumulativeTournament += dailyData[date]!['tournament']!;
        cumulativeCash += dailyData[date]!['cash']!;

        return {
          'date': date,
          'dateLabel': DateFormat('MMM d').format(date),
          'tournament': cumulativeTournament,
          'cash': cumulativeCash,
        };
      }).toList();

      setState(() {
        _chartData = chartData;
        _tournamentTotal = cumulativeTournament;
        _cashTotal = cumulativeCash;
        _firstSessionDate = sortedDates.first;
        _viewStart = _computeDefaultViewStart(chartData.length);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading earnings data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _computeDefaultViewStart(int total) {
    if (total <= _visiblePoints) return -0.5;
    return total - _visiblePoints - 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Solid dark surface — the green (accentPrimary) gradient corner was
        // removed for a cleaner chart backdrop.
        color: AppColors.surfaceVariant1,
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accentPrimary),
                )
              : _chartData.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildChart(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.earningsChartNoData,
                  style: AppTypography.ibm(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.earningsChartNoDataSubtitle,
                  style: AppTypography.ibm(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button — global left-chevron circle used across the app.
          BackButtonCircle(
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.earningsChartAllTimeEarnings,
                  style: AppTypography.ibm(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_firstSessionDate != null)
                  Text(
                    l10n.earningsChartSinceDate(DateFormat('MMM d, yyyy').format(_firstSessionDate!)),
                    style: AppTypography.ibm(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          // Legend
          _buildLegendItem(l10n.earningsChartTournament, AppColors.tournamentBlue),
          const SizedBox(width: 16),
          _buildLegendItem(l10n.earningsChartCash, AppColors.cashGameGreen),
          const SizedBox(width: 24),
          // Total
          _buildTotalBadge(_tournamentTotal + _cashTotal),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBadge(double amount) {
    final isNegative = amount < 0;
    final color = isNegative ? const Color(0xFFFF6B6B) : AppColors.profitGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDecorations.radius20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${isNegative ? "-" : ""}${CurrencyService.formatCash(amount.abs())}',
        style: AppTypography.ibm(
          fontSize: 16,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChart() {
    final data = _chartData;
    if (data.isEmpty) return const SizedBox.shrink();

    // Build spots for both lines
    final tournamentSpots = <FlSpot>[];
    final cashSpots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final t = (data[i]['tournament'] as num?)?.toDouble() ?? 0.0;
      final c = (data[i]['cash'] as num?)?.toDouble() ?? 0.0;
      tournamentSpots.add(FlSpot(i.toDouble(), t));
      cashSpots.add(FlSpot(i.toDouble(), c));
    }

    // Compute Y bounds based on visible window
    final viewStartIdx = _viewStart.floor().clamp(0, data.length - 1);
    final viewEndIdx = (_viewStart + (_visiblePoints - 1) + 1).ceil().clamp(0, data.length - 1);
    final visibleT = tournamentSpots.sublist(viewStartIdx, viewEndIdx + 1);
    final visibleC = cashSpots.sublist(viewStartIdx, viewEndIdx + 1);
    final allVisible = [...visibleT, ...visibleC];
    final rawMinY = allVisible.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = allVisible.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    // Always include $0 line
    final effectiveMin = math.min(rawMinY, 0.0);
    final effectiveMax = math.max(rawMaxY, 0.0);
    final yPadding = effectiveMax > effectiveMin
        ? (effectiveMax - effectiveMin) * 0.15
        : math.max(effectiveMax.abs(), 100.0) * 0.15;
    final minY = effectiveMin - yPadding;
    final maxY = effectiveMax + yPadding;
    final yRange = maxY > minY ? maxY - minY : 100.0;
    final yInterval = yRange / 4;

    // Viewport
    final viewWindow = (_visiblePoints - 1).toDouble() + 1.0;
    final viewMinX = _viewStart;
    final viewMaxX = _viewStart + viewWindow;

    // Scroll bounds
    final totalMaxX = (data.length - 1).toDouble() + 0.5;
    const scrollMin = -0.5;
    final scrollMax = (totalMaxX - viewWindow).clamp(scrollMin, double.infinity);

    return GestureDetector(
      onHorizontalDragUpdate: data.length > _visiblePoints
          ? (details) {
              final chartWidth = context.size?.width ?? 300;
              final unitsPerPixel = viewWindow / chartWidth;
              final delta = -details.delta.dx * unitsPerPixel;
              setState(() {
                _viewStart = (_viewStart + delta).clamp(scrollMin, scrollMax);
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
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 1,
              );
            },
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: Colors.white.withValues(alpha: 0.25),
                strokeWidth: 1,
                dashArray: [6, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 55,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    _formatYAxisValue(value),
                    style: AppTypography.mono(
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

                  // Show label every few points to avoid overlap
                  final visibleCount = (viewMaxX - viewMinX).round();
                  final labelInterval = math.max(1, visibleCount ~/ 5);
                  // Show first, last, and evenly spaced
                  if (idx != 0 &&
                      idx != data.length - 1 &&
                      idx % labelInterval != 0) {
                    return const SizedBox.shrink();
                  }

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6.0,
                    child: Text(
                      data[idx]['dateLabel'] as String,
                      style: AppTypography.ibm(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
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
            touchSpotThreshold: 40,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1C2926),
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // Keep the tooltip inside the chart bounds — it flips below the
              // point (or shifts sideways) instead of overflowing the top/edge.
              fitInsideVertically: true,
              fitInsideHorizontally: true,
              getTooltipItems: (touchedSpots) {
                final l10nChart = AppLocalizations.of(context);
              return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final value = spot.y;
                  final isT = spot.barIndex == 0;
                  final label = isT ? l10nChart.earningsChartMtt : l10nChart.earningsChartCash;
                  final color = isT ? AppColors.tournamentBlue : AppColors.cashGameGreen;
                  String dateLabel = '';
                  if (idx >= 0 && idx < data.length) {
                    dateLabel = '${data[idx]['dateLabel']}  ·  ';
                  }
                  return LineTooltipItem(
                    '$dateLabel$label: ${CurrencyService.formatCash(value)}',
                    AppTypography.ibm(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Tournament line
            LineChartBarData(
              spots: tournamentSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.tournamentBlue.withValues(alpha: 0.3),
                  AppColors.tournamentBlue,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.tournamentBlue,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.tournamentBlue.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Cash line
            LineChartBarData(
              spots: cashSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.cashGameGreen.withValues(alpha: 0.3),
                  AppColors.cashGameGreen,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.cashGameGreen,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.cashGameGreen.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
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

  String _formatYAxisValue(double value) {
    if (value.abs() >= 1000) {
      return CurrencyService.formatCompact(value);
    }
    return CurrencyService.formatCash(value);
  }
}
